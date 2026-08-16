param(
  [int]$Port = 18099
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$adapters = @(
  @{ Name = "order-domain"; Dir = "order-domain"; Args = "--addr :$Port --data-file `"$env:TEMP\smoke-order-data.json`""; Check = "/healthz" },
  @{ Name = "inventory-domain"; Dir = "inventory-domain"; Args = "--addr :$($Port + 1) --data-file `"$env:TEMP\smoke-inventory-data.json`""; Check = "/healthz" },
  @{ Name = "procurement-domain"; Dir = "procurement-domain"; Args = "--addr :$($Port + 2) --data-file `"$env:TEMP\smoke-procurement-data.json`""; Check = "/healthz" },
  @{ Name = "customer-domain"; Dir = "customer-domain"; Args = "--addr :$($Port + 3) --data-file `"$env:TEMP\smoke-customer-data.json`""; Check = "/healthz" }
)

$procs = @()
try {
  foreach ($a in $adapters) {
    $dir = Join-Path $repoRoot "adapters\$($a.Dir)"
    $env:GOWORK = "off"
    Push-Location $dir
    $exe = "$env:TEMP\smoke-$($a.Name)-adapter.exe"
    go build -o $exe .
    Pop-Location
    $p = Start-Process -FilePath $exe -ArgumentList $a.Args -PassThru -WindowStyle Hidden
    $procs += $p
  }
  Start-Sleep -Seconds 2

  $orderAddr = "http://localhost:$Port"
  $invAddr = "http://localhost:$($Port + 1)"
  $procAddr = "http://localhost:$($Port + 2)"
  $custAddr = "http://localhost:$($Port + 3)"

  $failures = @()
  function Assert-True($condition, $message) {
    if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
    else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
  }

  Assert-True ((Invoke-RestMethod -Uri "$orderAddr/healthz").status -eq "ok") "order-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$invAddr/healthz").status -eq "ok") "inventory-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$procAddr/healthz").status -eq "ok") "procurement-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$custAddr/healthz").status -eq "ok") "customer-domain adapter is healthy"

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

  # Procurement flow
  $procBase = "$procAddr/v1/requests/preq-0001"
  $submit = @{ requester = "e-1001"; idempotency_key = "smoke-proc-submit-v1" } | ConvertTo-Json
  $sub = Invoke-RestMethod -Method Post -Uri "$procBase/submit" -ContentType "application/json" -Body $submit
  Assert-True ($sub.request.status -eq "submitted") "procurement request is submitted"

  $selfDenied = $null
  try {
    $self = @{ role = "finance"; approver = "e-1001"; decision = "approve"; approval_ref = "approval://smoke"; idempotency_key = "smoke-proc-self-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $self | Out-Null
  } catch { $selfDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($selfDenied -eq 403) "requester self-approval is rejected (HTTP 403)"

  $fin = @{ role = "finance"; approver = "finance-lead"; decision = "approve"; approval_ref = "approval://smoke"; idempotency_key = "smoke-proc-fin-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $fin | Out-Null
  $pr = @{ role = "procurement"; approver = "procurement-owner"; decision = "approve"; approval_ref = "approval://smoke"; idempotency_key = "smoke-proc-pr-v1" } | ConvertTo-Json
  $apr = Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $pr
  Assert-True ($apr.request.status -eq "approved") "request approved after both roles approve"

  $buy = @{ supplier = "supplier-b"; approved_by = "procurement-owner"; approval_ref = "approval://smoke"; idempotency_key = "smoke-proc-buy-v1" } | ConvertTo-Json
  $po = Invoke-RestMethod -Method Post -Uri "$procBase/purchase-actions" -ContentType "application/json" -Body $buy
  Assert-True ($po.po.id -eq "po-preq-0001-supplier-b") "approved purchase issues the PO"

  $rcv = @{ received_by = "warehouse-receiver"; accepted = $true; idempotency_key = "smoke-proc-rcv-v1" } | ConvertTo-Json
  $rec = Invoke-RestMethod -Method Post -Uri "$procBase/receipts" -ContentType "application/json" -Body $rcv
  Assert-True ($rec.request.status -eq "closed") "receipt closes the request"

  # Customer case flow
  $custBase = "$custAddr/v1/cases/cs-0001"
  $fact = @{ claim = "overcharge confirmed"; source = "billing-system"; verified = $true; idempotency_key = "smoke-cs-fact-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$custBase/facts" -ContentType "application/json" -Body $fact | Out-Null

  $consentDenied = $null
  try {
    $premature = @{ type = "compensation"; amount = 40; approved_by = "service-lead"; approval_ref = "approval://smoke"; consent_ref = "consent://smoke"; idempotency_key = "smoke-cs-comp-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $premature | Out-Null
  } catch { $consentDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($consentDenied -eq 403) "compensation without consent is rejected (HTTP 403)"

  $consent = @{ customer = "cust-1001"; decision = "approve"; consent_ref = "consent://smoke"; idempotency_key = "smoke-cs-consent-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$custBase/consent" -ContentType "application/json" -Body $consent | Out-Null

  $approvalDenied = $null
  try {
    $noApproval = @{ type = "compensation"; amount = 40; approved_by = ""; approval_ref = ""; consent_ref = "consent://smoke"; idempotency_key = "smoke-cs-comp-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $noApproval | Out-Null
  } catch { $approvalDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($approvalDenied -eq 403) "compensation without approval is rejected (HTTP 403)"

  $res = @{ type = "compensation"; amount = 40; approved_by = "service-lead"; approval_ref = "approval://smoke"; consent_ref = "consent://smoke"; idempotency_key = "smoke-cs-comp-v1" } | ConvertTo-Json
  $applied = Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $res
  Assert-True ($applied.case.status -eq "resolving") "consented and approved compensation applies"

  $closeBody = @{ closed_by = "service-lead"; idempotency_key = "smoke-cs-close-v1" } | ConvertTo-Json
  $closed = Invoke-RestMethod -Method Post -Uri "$custBase/close" -ContentType "application/json" -Body $closeBody
  Assert-True ($closed.case.status -eq "resolved") "case closes after resolution"

  Write-Host ""
  if ($failures.Count -eq 0) { Write-Host "run-demo-smoke: all adapter-level checks passed." -ForegroundColor Green; exit 0 }
  Write-Host "run-demo-smoke: $($failures.Count) check(s) failed." -ForegroundColor Red
  exit 1
} finally {
  foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 500
  Get-Process | Where-Object { $_.Name -like "smoke-*" -or $_.Name -like "smoke*adapter*" } | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 300
  Remove-Item "$env:TEMP\smoke-*-adapter.exe" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-order-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-inventory-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-procurement-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-customer-data.json" -ErrorAction SilentlyContinue
}
