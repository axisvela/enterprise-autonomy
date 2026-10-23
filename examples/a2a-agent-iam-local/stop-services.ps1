param()

$processes = @("nomivela", "eidovelad", "aegivela-api", "limenora-server")
$stopped = @()
foreach ($name in $processes) {
  $items = Get-Process $name -ErrorAction SilentlyContinue
  if ($items) {
    $items | Stop-Process -Force -ErrorAction SilentlyContinue
    $stopped += $name
  }
}
if ($stopped.Count -eq 0) {
  Write-Host "No A2A Agent IAM services were running."
} else {
  Write-Host "Stopped: $($stopped -join ', ')"
}
