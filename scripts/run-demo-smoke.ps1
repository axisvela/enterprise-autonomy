param(
  [int]$Port = 18099
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$adapters = @(
  @{ Name = "order-domain"; Dir = "order-domain"; Args = "--addr :$Port --data-file `"$env:TEMP\smoke-order-data.json`""; Check = "/healthz" },
  @{ Name = "inventory-domain"; Dir = "inventory-domain"; Args = "--addr :$($Port + 1) --data-file `"$env:TEMP\smoke-inventory-data.json`""; Check = "/healthz" }
)

$procs = @()
try {
  foreach ($a in $adapters) {
    $dir = Join-Path $repoRoot "adapters\$($a.Dir)"
    $env:GOWORK = "off"
    Push-Location $dir
    go build -o $env:TEMP\smoke-adapter.exe .
    Pop-Location
    $p = Start-Process -FilePath $env:TEMP\smoke-adapter.exe -ArgumentList $a.Args -PassThru -WindowStyle Hidden
    $procs += $p
  }
  Start-Sleep -Seconds 2

  $orderAddr = "http://localhost:$Port"
  $invAddr = "http://localhost:$($Port + 1)"

  $failures = @()
  function Assert-True($condition, $message) {
    if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
    else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
  }

  Assert-True ((Invoke-RestMethod -Uri "$orderAddr/healthz").status -eq "ok") "order-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$invAddr/healthz").status -eq "ok") "inventory-domain adapter is healthy"

  $order = Invoke-RestMethod -Uri "$orderAddr/v1/orders/order-123"
  Assert-True ($order.fulfillment_status -eq "stockout") "order starts in stockout"

  $inv = Invoke-RestMethod -Uri "$invAddr/v1/inventory/sku-inspection-kit"
  Assert-True (($inv.levels | Where-Object { $_.warehouse -eq "warehouse-b" }).available -eq 10) "inventory starts with 10 at warehouse-b"

  $reservation = @{ warehouse = "warehouse-b"; delta = -1; reason = "smoke reserve"; approved_by = "smoke-operator"; approval_ref = "approval://smoke"; idempotency_key = "smoke-reserve-v1" } | ConvertTo-Json
  $adj = Invoke-RestMethod -Method Post -Uri "$invAddr/v1/inventory/sku-inspection-kit" -ContentType "application/json" -Body $reservation
  Assert-True ($adj.adjustment.delta -eq -1) "inventory reservation applied"

  $denied = $null
  try {
    $bad = @{ action = "alternate_location"; approved_by = ""; approval_ref = ""; idempotency_key = "smoke-bad-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$orderAddr/v1/orders/order-123/fulfillment-actions" -ContentType "application/json" -Body $bad | Out-Null
  } catch { $denied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($denied -eq 400) "unapproved action is rejected (HTTP 400)"

  $good = @{ action = "alternate_location"; approved_by = "smoke-operator"; approval_ref = "approval://smoke"; idempotency_key = "smoke-order-v1" } | ConvertTo-Json
  $res = Invoke-RestMethod -Method Post -Uri "$orderAddr/v1/orders/order-123/fulfillment-actions" -ContentType "application/json" -Body $good
  Assert-True ($res.order.fulfillment_status -eq "replanned") "approved action moves order to replanned"

  Write-Host ""
  if ($failures.Count -eq 0) { Write-Host "run-demo-smoke: all adapter-level checks passed." -ForegroundColor Green; exit 0 }
  Write-Host "run-demo-smoke: $($failures.Count) check(s) failed." -ForegroundColor Red
  exit 1
} finally {
  foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  Remove-Item "$env:TEMP\smoke-adapter.exe" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-order-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-inventory-data.json" -ErrorAction SilentlyContinue
}
