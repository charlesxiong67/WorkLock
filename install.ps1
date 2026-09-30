# Installs WorkLock for the current Windows user. No admin needed.
#   - copies the app to %LOCALAPPDATA%\WorkLock
#   - starts the watcher now and at every logon (HKCU Run key)
#   - puts a "WorkLock Tasks" shortcut on the desktop
$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dst = Join-Path $env:LOCALAPPDATA 'WorkLock'

# Stop a running watcher so its files can be replaced.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*WorkLock.ps1*' -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

New-Item -ItemType Directory -Force $dst | Out-Null
$files = 'WorkLock.ps1', 'Tasks.ps1', 'common.ps1', 'launcher.vbs', 'tasks.vbs', 'uninstall.ps1'
foreach ($f in $files) { Copy-Item (Join-Path $src $f) $dst -Force }
# Keep an existing config (the user may have added games).
if (-not (Test-Path (Join-Path $dst 'config.json'))) { Copy-Item (Join-Path $src 'config.json') $dst }

Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name WorkLock `
    -Value "`"$env:WINDIR\System32\wscript.exe`" `"$dst\launcher.vbs`""

$desk = [Environment]::GetFolderPath('Desktop')
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk 'WorkLock Tasks.lnk'))
$lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
$lnk.Arguments = "`"$dst\tasks.vbs`""
$lnk.WorkingDirectory = $dst
$lnk.IconLocation = "$env:WINDIR\System32\imageres.dll,54"
$lnk.Description = 'Add and tick off your work'
$lnk.Save()

Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList "`"$dst\launcher.vbs`""
Write-Host "WorkLock installed to $dst and running."
Write-Host "Open 'WorkLock Tasks' on your desktop to add today's work."
