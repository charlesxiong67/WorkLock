# WorkLock watcher. Every CheckSeconds (default 60) it closes any game it finds
# while today's work isn't finished. Started hidden at logon by launcher.vbs.
$ErrorActionPreference = 'SilentlyContinue'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mutex = New-Object System.Threading.Mutex($false, 'Local\WorkLockWatcher')
if (-not $mutex.WaitOne(0)) { exit }   # already running

. (Join-Path $Here 'common.ps1')
$LogFile = Join-Path (Get-WLDataDir $Here) 'worklock.log'
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content $LogFile }

function Find-Games($cfg) {
    $names = @($cfg.GameProcesses)
    $found = @(Get-Process | Where-Object {
        $p = $_
        ($names -contains $p.ProcessName) -or
        ($p.Path -and ($cfg.GamePaths | Where-Object { $p.Path -like "*$_*" }))
    })
    $pat = ($cfg.JavaCommandLinePatterns -join '|')
    $java = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" |
        Where-Object { $_.CommandLine -match $pat }
    foreach ($j in $java) { $found += Get-Process -Id $j.ProcessId }
    $found | Where-Object { $_.Id -ne $PID }
}

function Show-Popup($msg) {
    $f = Join-Path $env:TEMP ('worklock-' + [guid]::NewGuid() + '.txt')
    Set-Content $f $msg -Encoding UTF8
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-Command',
        "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show((Get-Content '$f' -Raw -Encoding UTF8), 'WorkLock', 'OK', 'Warning', 'Button1', 'DefaultDesktopOnly'); Remove-Item '$f'"
}

$lastPopup = [datetime]::MinValue
Log 'watcher started'
while ($true) {
    $s = Get-WLState $Here
    if ($s.Locked) {
        $games = @(Find-Games $s.Cfg)
        if ($games.Count -gt 0) {
            $names = ($games | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
            $games | Stop-Process -Force
            Log "closed: $names"
            if (((Get-Date) - $lastPopup).TotalMinutes -ge 2) {
                $lastPopup = Get-Date
                $msg = if (-not $s.HasToday) {
                    "Games are locked.`n`nOpen 'WorkLock Tasks' on your desktop and add today's work. When it's all ticked off, games unlock."
                } else {
                    "Games are locked. Still to do:`n`n" + (($s.Left | ForEach-Object { "  - $_" }) -join "`n")
                }
                Show-Popup $msg
            }
        }
    }
    Start-Sleep -Seconds ([math]::Max(5, [int]$s.Cfg.CheckSeconds))
}
