# Installs restart-on-reboot: writes two launchers into the Startup folder that
# invoke this repo's start-*.vbs by absolute path, then launches runner + guardian
# now. No elevation needed. Re-runnable (mutexes prevent duplicate processes).
$here    = $PSScriptRoot
$startup = [Environment]::GetFolderPath('Startup')

function New-StartupLauncher($targetVbs, $dest) {
  $content = 'CreateObject("WScript.Shell").Run "wscript.exe ""' + $targetVbs + '""", 0, False'
  Set-Content -Path $dest -Value $content -Encoding ASCII
}

New-StartupLauncher (Join-Path $here 'start-runner.vbs')   (Join-Path $startup 'gpu-puzzle-runner.vbs')
New-StartupLauncher (Join-Path $here 'start-guardian.vbs') (Join-Path $startup 'gpu-puzzle-guardian.vbs')

Start-Process 'wscript.exe' -ArgumentList (Join-Path $here 'start-runner.vbs')
Start-Sleep -Seconds 3
Start-Process 'wscript.exe' -ArgumentList (Join-Path $here 'start-guardian.vbs')

Write-Output "Autostart installed to: $startup"
Write-Output 'Runner + guardian launched, and will relaunch at each logon.'
