# Shared by the watcher and the task window.
# Daily tasks live in data\tasks.json (unfinished ones carry over to the next day).
# Weekly tasks live in data\weekly.json and come back every Monday.

function Get-WLDataDir($Here) {
    $d = Join-Path $Here 'data'
    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
    $d
}

function Read-WLJson($path) {
    if (-not (Test-Path $path)) { return $null }
    try { Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
}

function Get-WLState($Here) {
    $cfg = Read-WLJson (Join-Path $Here 'config.json')
    $data = Get-WLDataDir $Here
    $now = (Get-Date).AddHours(-[int]$cfg.ResetHour)
    $day = $now.ToString('yyyy-MM-dd')
    $week = $now.Date.AddDays(-(([int]$now.DayOfWeek + 6) % 7)).ToString('yyyy-MM-dd')   # Monday

    $t = Read-WLJson (Join-Path $data 'tasks.json')
    if (-not $t -or $t.date -ne $day) {
        $carry = @(if ($t) { $t.tasks | Where-Object { -not $_.done } })
        $t = [pscustomobject]@{ date = $day; noWork = $false; tasks = $carry }
    }
    # PowerShell 5.1 hands a JSON array back as one object; the pipeline unrolls it.
    $weekly = @((Read-WLJson (Join-Path $data 'weekly.json')) | ForEach-Object { $_ } | Where-Object { $_.text })

    $left  = @($t.tasks | Where-Object { -not $_.done } | ForEach-Object { $_.text })
    $wleft = @($weekly | Where-Object { $_.doneWeek -ne $week } | ForEach-Object { $_.text })
    $hasList = [bool]($t.noWork -or @($t.tasks).Count -gt 0)
    [pscustomobject]@{
        Cfg = $cfg; Day = $day; Week = $week; Today = $t; Weekly = $weekly
        HasToday = $hasList
        Left = @($left + $wleft)
        Locked = (-not $hasList) -or $left.Count -gt 0 -or $wleft.Count -gt 0
    }
}

function Save-WLState($Here, $today, $weekly) {
    $data = Get-WLDataDir $Here
    $today | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $data 'tasks.json') -Encoding UTF8
    ConvertTo-Json -InputObject @($weekly) -Depth 4 | Set-Content (Join-Path $data 'weekly.json') -Encoding UTF8
}

function Get-WLHash($text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("WorkLock:" + $text)) | ForEach-Object { $_.ToString('x2') }) -join ''
}
