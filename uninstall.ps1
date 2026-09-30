# Removes WorkLock: stops the watcher, removes it from startup, deletes the shortcut and files.
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name WorkLock -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { ($_.CommandLine -like '*WorkLock.ps1*' -or $_.CommandLine -like '*Tasks.ps1*') -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'WorkLock Tasks.lnk') -ErrorAction SilentlyContinue
$dir = Join-Path $env:LOCALAPPDATA 'WorkLock'
Set-Location $env:TEMP
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'WorkLock removed.'
