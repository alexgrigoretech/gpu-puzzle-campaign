' Launches the campaign runner hidden (no console window). Portable: resolves
' its own folder, so it works wherever the repo is cloned.
Dim fso, here
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & here & "\run-campaign.ps1""", 0, False
