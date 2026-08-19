# Guardian: keeps the campaign runner alive. If the runner process is gone and no
# solver is running, relaunch it (the runner's own mutex prevents duplicates).
# No elevation required.
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$log  = Join-Path $here 'guardian.log'
function Log($m){ Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }

$mtx = New-Object System.Threading.Mutex($false, 'GpuPuzzleCampaignGuardian')
$own = $false
try { $own = $mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $own = $true }
if (-not $own) { exit 0 }

$cfg = @('config.ps1','config.example.ps1') | ForEach-Object { Join-Path $here $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
. $cfg
$solverName = [IO.Path]::GetFileNameWithoutExtension($Exe)

Log 'guardian up'
$miss = 0
while ($true) {
  $runnerAlive = $true
  try { $r = [System.Threading.Mutex]::OpenExisting('GpuPuzzleCampaignRunner'); $r.Dispose() } catch { $runnerAlive = $false }
  # relaunch only if the runner mutex is gone AND no solver process (tolerates brief between-chunk gaps)
  if (-not $runnerAlive -and -not (Get-Process -Name $solverName -ErrorAction SilentlyContinue)) { $miss++ } else { $miss = 0 }
  if ($miss -ge 2) {
    Log 'runner down -> relaunching'
    Start-Process 'wscript.exe' -ArgumentList (Join-Path $here 'start-runner.vbs')
    $miss = 0
    Start-Sleep -Seconds 20
  }
  Start-Sleep -Seconds 60
}
