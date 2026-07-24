# Keep Render awake so Africa's Talking USSD does not time out.
# Run this in a separate PowerShell window during your defense demo.

$health = "https://ecowatch-wu20.onrender.com/health"
Write-Host "Pinging $health every 5 minutes. Ctrl+C to stop."
while ($true) {
  try {
    $r = Invoke-WebRequest -Uri $health -UseBasicParsing -TimeoutSec 90
    Write-Host "$(Get-Date -Format HH:mm:ss) $($r.StatusCode) $($r.Content)"
  } catch {
    Write-Host "$(Get-Date -Format HH:mm:ss) FAIL $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 300
}
