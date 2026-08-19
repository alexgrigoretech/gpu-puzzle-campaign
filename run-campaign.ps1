# GPU puzzle campaign runner.
# Sweeps the configured keyspace upward in fixed chunks, appending each completed
# chunk to ledger.csv and saving the next start to state.txt, so it never
# re-scans and resumes exactly after any stop, crash, or reboot. Single instance
# via a named mutex. Retries a chunk on non-zero exit. Writes FOUND.flag if the
# solver's Found.txt grows.
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot

# load config (prefer config.ps1, fall back to the example defaults)
$cfg = @('config.ps1','config.example.ps1') | ForEach-Object { Join-Path $here $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
. $cfg

$logF     = Join-Path $here 'runner.log'
$ledger   = Join-Path $here 'ledger.csv'
$stateF   = Join-Path $here 'state.txt'
$flagF    = Join-Path $here 'FOUND.flag'
$tmpOut   = Join-Path $here '_chunk_out.txt'
$foundTxt = Join-Path (Split-Path $Exe) 'Found.txt'

function Log($m){ Add-Content -Path $logF -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }

if (-not (Test-Path $Exe)) { Log "ERROR: solver not found at '$Exe'. Set `$Exe in config.ps1 (see BUILD.md)."; exit 1 }

# single instance (abandoned mutex => prior runner died, we take over)
$mtx = New-Object System.Threading.Mutex($false, 'GpuPuzzleCampaignRunner')
$own = $false
try { $own = $mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $own = $true }
if (-not $own) { exit 0 }

$rangeEnd = [bigint]::Parse('0' + $RangeEndHex, 'AllowHexSpecifier')
$chunk    = [bigint]::Pow(2, $ChunkPow)

if (Test-Path $stateF) {
  $next = [bigint]::Parse('0' + ((Get-Content $stateF -Raw).Trim()), 'AllowHexSpecifier')
} else {
  $next = [bigint]::Parse('0' + $RangeStartHex, 'AllowHexSpecifier')
  Set-Content -Path $stateF -Value ($next.ToString('x'))
}
if (-not (Test-Path $ledger)) { Set-Content -Path $ledger -Value 'chunk_start_hex,chunk_end_hex,keys,completed_utc,last_speed' }
$foundBase = if (Test-Path $foundTxt) { (Get-Item $foundTxt).Length } else { 0 }

Log ("runner up; next={0} end={1} chunk=2^{2}" -f $next.ToString('x'), $rangeEnd.ToString('x'), $ChunkPow)

while ($true) {
  if ($next -gt $rangeEnd) { Log 'RANGE EXHAUSTED - stopping'; break }
  $endThis = $next + $chunk - 1
  if ($endThis -gt $rangeEnd) { $endThis = $rangeEnd }
  $curHex = $next.ToString('x')
  $cntHex = ((($endThis - $next) + 1)).ToString('x')

  & $Exe -g --gpux $Grid -m ADDRESS --coin BTC --range ("{0}:+{1}" -f $curHex, $cntHex) $Address *> $tmpOut
  $ec = $LASTEXITCODE

  $sz = if (Test-Path $foundTxt) { (Get-Item $foundTxt).Length } else { 0 }
  if ($sz -gt $foundBase) {
    Set-Content -Path $flagF -Value ("HIT near chunk {0} at {1}" -f $curHex, (Get-Date -Format 'u'))
    Log ("*** HIT DETECTED near chunk {0} - see Found.txt next to the solver ***" -f $curHex)
    break
  }

  if ($ec -eq 0) {
    $speed = ''
    if (Test-Path $tmpOut) {
      $mm = [regex]::Matches((Get-Content $tmpOut -Raw), '([\d.]+)\s*Mk/s')
      if ($mm.Count -gt 0) { $speed = $mm[$mm.Count-1].Groups[1].Value + ' Mk/s' }
    }
    Add-Content -Path $ledger -Value ("{0},{1},{2},{3},{4}" -f $curHex, $endThis.ToString('x'), $chunk.ToString(), (Get-Date -Format 'u'), $speed)
    $next = $endThis + 1
    Set-Content -Path $stateF -Value ($next.ToString('x'))
  } else {
    Log ("solver exit={0} on chunk {1}; retry in 10s" -f $ec, $curHex)
    Start-Sleep -Seconds 10
  }
}
try { $mtx.ReleaseMutex() } catch {}
