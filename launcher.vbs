' Starts the WorkLock watcher with no window.
Dim here
here = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & here & "\WorkLock.ps1""", 0, False
