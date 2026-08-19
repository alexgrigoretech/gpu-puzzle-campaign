# One-time ELEVATED setup: cap the GPU during work hours, release it after.
# Run from an elevated PowerShell (nvidia-smi -pl needs admin). Applies the cap
# now and registers two SYSTEM scheduled tasks so it repeats daily. Edit the
# values below for your card and hours. Optional; the campaign runs fine without it.
$CapWatts  = 240              # limit during work hours (pick a value your card allows)
$FullWatts = 285             # default/off-hours limit (your card's stock limit)
$CapAt     = [datetime]'09:00'
$ResetAt   = [datetime]'18:00'
$smi = Join-Path $env:WINDIR 'System32\nvidia-smi.exe'

& $smi -pl $CapWatts

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set       = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName 'GpuPuzzle-Cap' -Force -Principal $principal -Settings $set `
  -Action  (New-ScheduledTaskAction -Execute $smi -Argument "-pl $CapWatts") `
  -Trigger (New-ScheduledTaskTrigger -Daily -At $CapAt)

Register-ScheduledTask -TaskName 'GpuPuzzle-Reset' -Force -Principal $principal -Settings $set `
  -Action  (New-ScheduledTaskAction -Execute $smi -Argument "-pl $FullWatts") `
  -Trigger (New-ScheduledTaskTrigger -Daily -At $ResetAt)

Write-Output ("Applied {0}W now. Scheduled: {0}W at {1}, {2}W at {3} daily." -f $CapWatts, $CapAt.ToString('HH:mm'), $FullWatts, $ResetAt.ToString('HH:mm'))
& $smi --query-gpu=power.limit,temperature.gpu --format=csv,noheader
