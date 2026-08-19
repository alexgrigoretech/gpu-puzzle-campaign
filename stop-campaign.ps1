# Fully stop the campaign: remove autostart, kill runner/guardian/solver.
# state.txt + ledger.csv are preserved, so a later relaunch resumes where it left off.
$here    = $PSScriptRoot
$startup = [Environment]::GetFolderPath('Startup')
Remove-Item (Join-Path $startup 'gpu-puzzle-runner.vbs')   -ErrorAction SilentlyContinue
Remove-Item (Join-Path $startup 'gpu-puzzle-guardian.vbs') -ErrorAction SilentlyContinue

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -match 'run-campaign\.ps1|guardian\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$cfg = @('config.ps1','config.example.ps1') | ForEach-Object { Join-Path $here $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
. $cfg
$solverName = [IO.Path]::GetFileNameWithoutExtension($Exe)
Stop-Process -Name $solverName -Force -ErrorAction SilentlyContinue

Write-Output 'Campaign stopped and autostart removed. Ledger/state kept; relaunch resumes.'
