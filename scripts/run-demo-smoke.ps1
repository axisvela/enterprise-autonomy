param(
  [int]$Port = 18099
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$adapters = @(
  @{ Name = "order-domain"; Dir = "order-domain"; Args = "--addr :$Port --data-file `"$env:TEMP\smoke-order-data.json`""; Check = "/healthz" },
  @{ Name = "inventory-domain"; Dir = "inventory-domain"; Args = "--addr :$($Port + 1) --data-file `"$env:TEMP\smoke-inventory-data.json`""; Check = "/healthz" },
  @{ Name = "procurement-domain"; Dir = "procurement-domain"; Args = "--addr :$($Port + 2) --data-file `"$env:TEMP\smoke-procurement-data.json`""; Check = "/healthz" },
  @{ Name = "customer-domain"; Dir = "customer-domain"; Args = "--addr :$($Port + 3) --data-file `"$env:TEMP\smoke-customer-data.json`""; Check = "/healthz" },
  @{ Name = "recruitment-domain"; Dir = "recruitment-domain"; Args = "--addr :$($Port + 4) --data-file `"$env:TEMP\smoke-recruitment-data.json`""; Check = "/healthz" },
  @{ Name = "maintenance-domain"; Dir = "maintenance-domain"; Args = "--addr :$($Port + 5) --data-file `"$env:TEMP\smoke-maintenance-data.json`""; Check = "/healthz" },
  @{ Name = "integration-domain"; Dir = "integration-domain"; Args = "--addr :$($Port + 6) --data-file `"$env:TEMP\smoke-integration-data.json`""; Check = "/healthz" }
)

$procs = @()
try {
  foreach ($a in $adapters) {
    $dir = Join-Path $repoRoot "adapters\$($a.Dir)"
    $env:GOWORK = "off"
    Push-Location $dir
    $exe = "$env:TEMP\smoke-$($a.Name)-adapter.exe"
    Remove-Item $exe -ErrorAction SilentlyContinue
    go build -o $exe .
    if ($LASTEXITCODE -ne 0) { throw "build failed for $($a.Name)" }
    Pop-Location
    $p = Start-Process -FilePath $exe -ArgumentList $a.Args -PassThru -WindowStyle Hidden
    $procs += $p
  }
  Start-Sleep -Seconds 2

  $orderAddr = "http://localhost:$Port"
  $invAddr = "http://localhost:$($Port + 1)"
  $procAddr = "http://localhost:$($Port + 2)"
  $custAddr = "http://localhost:$($Port + 3)"
  $recAddr = "http://localhost:$($Port + 4)"
  $maintAddr = "http://localhost:$($Port + 5)"
  $intAddr = "http://localhost:$($Port + 6)"

  $failures = @()
  function Assert-True($condition, $message) {
    if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
    else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
  }

  Assert-True ((Invoke-RestMethod -Uri "$orderAddr/healthz").status -eq "ok") "order-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$invAddr/healthz").status -eq "ok") "inventory-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$procAddr/healthz").status -eq "ok") "procurement-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$custAddr/healthz").status -eq "ok") "customer-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$recAddr/healthz").status -eq "ok") "recruitment-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$maintAddr/healthz").status -eq "ok") "maintenance-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$intAddr/healthz").status -eq "ok") "integration-domain adapter is healthy"

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

  # Recruitment flow
  $recBase = "$recAddr/v1/requisitions/req-0001"
  $validate = @{ validated_by = "ta-lead-1"; criteria = @("platform-expertise"); idempotency_key = "smoke-rec-val-v1" } | ConvertTo-Json
  $val = Invoke-RestMethod -Method Post -Uri "$recBase/validate" -ContentType "application/json" -Body $validate
  Assert-True ($val.requisition.status -eq "validated") "requisition is validated by the TA lead"

  $autoDenied = $null
  try {
    $auto = @{ stage = "shortlist"; decision = "advance"; candidate = "cand-a"; decided_by = "recruiter-assistant"; actor_type = "automated"; rationale = "keyword"; decision_ref = "decision://smoke"; idempotency_key = "smoke-rec-auto-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $auto | Out-Null
  } catch { $autoDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($autoDenied -eq 403) "automated hiring decision is rejected (HTTP 403)"

  $sl = @{ stage = "shortlist"; decision = "advance"; candidate = "cand-a"; decided_by = "panel-1"; actor_type = "human"; rationale = "meets criteria"; decision_ref = "decision://smoke"; idempotency_key = "smoke-rec-sl-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $sl | Out-Null
  $sel = @{ stage = "selection"; decision = "select"; candidate = "cand-a"; decided_by = "hiring-manager-1"; actor_type = "human"; rationale = "best evidence"; decision_ref = "decision://smoke"; idempotency_key = "smoke-rec-sel-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $sel | Out-Null
  $ofd = @{ stage = "offer"; decision = "offer"; candidate = "cand-a"; decided_by = "hiring-manager-1"; actor_type = "human"; rationale = "approved"; decision_ref = "decision://smoke"; idempotency_key = "smoke-rec-of-v1" } | ConvertTo-Json
  $ofdResult = Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $ofd
  Assert-True ($ofdResult.requisition.status -eq "offer") "human decisions advance to offer stage"

  $offer = @{ candidate = "cand-a"; offered_by = "ta-lead-1"; offer_ref = "offer://smoke"; idempotency_key = "smoke-rec-offer-v1" } | ConvertTo-Json
  $of = Invoke-RestMethod -Method Post -Uri "$recBase/offers" -ContentType "application/json" -Body $offer
  Assert-True ($of.requisition.status -eq "closed") "offer closes the requisition"

  # Maintenance flow
  $maintBase = "$maintAddr/v1/signals/signal-pm-0001"
  $prematureWO = $null
  try {
    $premature = @{ scope = "replace bearing"; approved_by = "maintenance-manager"; approval_ref = "approval://smoke"; idempotency_key = "smoke-maint-wo-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $premature | Out-Null
  } catch { $prematureWO = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($prematureWO -eq 403) "work order on unvalidated signal is rejected (HTTP 403)"

  $val = @{ validated_by = "maintenance-manager"; confirmed = $false; note = "prediction"; idempotency_key = "smoke-maint-val-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/validate" -ContentType "application/json" -Body $val | Out-Null

  $stopDenied = $null
  try {
    $stop = @{ decision = "stop"; decided_by = "maintenance-manager"; decision_ref = "decision://smoke"; idempotency_key = "smoke-maint-stop-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$maintBase/decisions" -ContentType "application/json" -Body $stop | Out-Null
  } catch { $stopDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($stopDenied -eq 403) "unconfirmed prediction cannot trigger stop (HTTP 403)"

  $dec = @{ decision = "repair"; decided_by = "maintenance-manager"; decision_ref = "decision://smoke"; idempotency_key = "smoke-maint-dec-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/decisions" -ContentType "application/json" -Body $dec | Out-Null

  $noSafety = $null
  try {
    $wo = @{ scope = "replace bearing"; approved_by = "maintenance-manager"; approval_ref = "approval://smoke"; idempotency_key = "smoke-maint-wo-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $wo | Out-Null
  } catch { $noSafety = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($noSafety -eq 403) "work order without safety review is rejected (HTTP 403)"

  $safety = @{ reviewed_by = "safety-authority"; outcome = "approve"; safety_ref = "safety://smoke"; idempotency_key = "smoke-maint-safety-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/safety-reviews" -ContentType "application/json" -Body $safety | Out-Null
  $woFinal = @{ scope = "replace bearing"; approved_by = "maintenance-manager"; approval_ref = "approval://smoke"; idempotency_key = "smoke-maint-wo-v1" } | ConvertTo-Json
  $maintResult = Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $woFinal
  Assert-True ($maintResult.work_order.status -eq "scheduled") "safety-reviewed work order is scheduled"

  # Integration recovery flow
  $intWork = "$intAddr/v1/work/work-0001"
  $resumeDenied = $null
  try {
    $prematureResume = @{ resumed_by = "integration-owner"; idempotency_key = "smoke-int-resume-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$intWork/resume" -ContentType "application/json" -Body $prematureResume | Out-Null
  } catch { $resumeDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($resumeDenied -eq 403) "resume before preservation is rejected (HTTP 403)"

  $pres = @{ preserved_by = "integration-owner"; preserved_ref = "process://smoke"; idempotency_key = "smoke-int-pres-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$intWork/preserve" -ContentType "application/json" -Body $pres | Out-Null

  $verifyDenied = $null
  try {
    $prematureResume2 = @{ resumed_by = "integration-owner"; idempotency_key = "smoke-int-resume-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$intWork/resume" -ContentType "application/json" -Body $prematureResume2 | Out-Null
  } catch { $verifyDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($verifyDenied -eq 403) "resume before verification is rejected (HTTP 403)"

  $ck = @{ checked_by = "integration-owner"; verified = $true; evidence_ref = "evidence://smoke"; idempotency_key = "smoke-int-check-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$intAddr/v1/integrations/partner-shipping/checks" -ContentType "application/json" -Body $ck | Out-Null
  $resume = @{ resumed_by = "integration-owner"; idempotency_key = "smoke-int-resume-v1" } | ConvertTo-Json
  $resumeResult = Invoke-RestMethod -Method Post -Uri "$intWork/resume" -ContentType "application/json" -Body $resume
  Assert-True ($resumeResult.work.status -eq "resumed") "verified work resumes"

  $comp = @{ completed_by = "integration-owner"; idempotency_key = "smoke-int-comp-v1" } | ConvertTo-Json
  $compResult = Invoke-RestMethod -Method Post -Uri "$intWork/complete" -ContentType "application/json" -Body $comp
  $rerunDenied = $null
  try {
    $comp2 = @{ completed_by = "integration-owner"; idempotency_key = "smoke-int-comp2-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$intWork/complete" -ContentType "application/json" -Body $comp2 | Out-Null
  } catch { $rerunDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($compResult.work.status -eq "completed") "work completes after verified resume"
  Assert-True ($rerunDenied -eq 409) "silent re-execution is rejected (HTTP 409)"

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
  Remove-Item "$env:TEMP\smoke-recruitment-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-maintenance-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-integration-data.json" -ErrorAction SilentlyContinue
}
