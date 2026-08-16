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
  @{ Name = "integration-domain"; Dir = "integration-domain"; Args = "--addr :$($Port + 6) --data-file `"$env:TEMP\smoke-integration-data.json`""; Check = "/healthz" },
  @{ Name = "simulation-domain"; Dir = "simulation-domain"; Args = "--addr :$($Port + 7) --data-file `"$env:TEMP\smoke-simulation-data.json`""; Check = "/healthz" },
  @{ Name = "compliance-domain"; Dir = "compliance-domain"; Args = "--addr :$($Port + 8) --data-file `"$env:TEMP\smoke-compliance-data.json`""; Check = "/healthz" },
  @{ Name = "fleet-domain"; Dir = "fleet-domain"; Args = "--addr :$($Port + 9) --data-file `"$env:TEMP\smoke-fleet-data.json`""; Check = "/healthz" }
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
  $simAddr = "http://localhost:$($Port + 7)"
  $compAddr = "http://localhost:$($Port + 8)"
  $fleetAddr = "http://localhost:$($Port + 9)"

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
  Assert-True ((Invoke-RestMethod -Uri "$simAddr/healthz").status -eq "ok") "simulation-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$compAddr/healthz").status -eq "ok") "compliance-domain adapter is healthy"
  Assert-True ((Invoke-RestMethod -Uri "$fleetAddr/healthz").status -eq "ok") "fleet-domain adapter is healthy"

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

  # Simulation validation flow
  $simBase = "$simAddr/v1/proposals/proposal-sim-0001"
  $decDenied = $null
  try {
    $prematureDec = @{ decision = "approve"; decided_by = "reviewer-a"; rationale = "premature"; decision_ref = "decision://smoke"; idempotency_key = "smoke-sim-dec-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $prematureDec | Out-Null
  } catch { $decDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($decDenied -eq 403) "decision without simulation evidence is rejected (HTTP 403)"

  $sc = @{ scenario_id = "scn-collision"; description = "collision avoidance"; idempotency_key = "smoke-sim-scn-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$simBase/scenarios" -ContentType "application/json" -Body $sc | Out-Null
  $run = @{ run_id = "run-001"; outcome = "pass"; evidence_ref = "evidence://smoke"; recorded_by = "simulation-engineer"; idempotency_key = "smoke-sim-run-v1" } | ConvertTo-Json
  $runResult = Invoke-RestMethod -Method Post -Uri "$simBase/runs" -ContentType "application/json" -Body $run
  Assert-True ($runResult.run.immutable -eq $true) "simulation evidence is recorded immutable"

  $immutableDenied = $null
  try {
    $run2 = @{ run_id = "run-002"; outcome = "fail"; evidence_ref = "evidence://smoke-2"; recorded_by = "simulation-engineer"; idempotency_key = "smoke-sim-run2-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$simBase/runs" -ContentType "application/json" -Body $run2 | Out-Null
  } catch { $immutableDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($immutableDenied -eq 409) "immutable evidence cannot be replaced (HTTP 409)"

  $nonMember = $null
  try {
    $outsider = @{ decision = "approve"; decided_by = "outsider"; rationale = "x"; decision_ref = "decision://smoke"; idempotency_key = "smoke-sim-dec-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $outsider | Out-Null
  } catch { $nonMember = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($nonMember -eq 403) "non-review-group decision is rejected (HTTP 403)"

  $dec = @{ decision = "approve"; decided_by = "reviewer-a"; rationale = "evidence passes"; decision_ref = "decision://smoke"; idempotency_key = "smoke-sim-dec-v1" } | ConvertTo-Json
  $decResult = Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $dec
  Assert-True ($decResult.proposal.status -eq "decided") "review-group decision is recorded"

  $rel = @{ released_by = "reviewer-a"; decision_ref = "decision://smoke"; idempotency_key = "smoke-sim-rel-v1" } | ConvertTo-Json
  $relResult = Invoke-RestMethod -Method Post -Uri "$simBase/release" -ContentType "application/json" -Body $rel
  Assert-True ($relResult.proposal.status -eq "released") "evidence-gated release completes"

  # Compliance flow
  $compBase = "$compAddr/v1/compliance/compliance-0001"
  $attDenied = $null
  try {
    $premature = @{ attested_by = "compliance-lead"; decision = "attest"; attestation_ref = "attestation://smoke"; idempotency_key = "smoke-comp-att-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $premature | Out-Null
  } catch { $attDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($attDenied -eq 403) "attestation before complete evidence is rejected (HTTP 403)"

  for ($i = 1; $i -le 4; $i++) {
    $ev = @{ item_id = "evidence-item-$i"; source = "governed-source-$i"; timestamp = "2026-08-16T14:0$i`:00Z"; evidence_ref = "evidence://smoke/item-$i"; collected_by = "compliance-lead"; idempotency_key = "smoke-comp-ev-$i" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$compBase/evidence" -ContentType "application/json" -Body $ev | Out-Null
  }

  $nonAttestor = $null
  try {
    $outsider = @{ attested_by = "outsider"; decision = "attest"; attestation_ref = "attestation://smoke"; idempotency_key = "smoke-comp-att-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $outsider | Out-Null
  } catch { $nonAttestor = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($nonAttestor -eq 403) "non-designated attestor is rejected (HTTP 403)"

  $att = @{ attested_by = "compliance-lead"; decision = "attest"; attestation_ref = "attestation://smoke"; idempotency_key = "smoke-comp-att-v1" } | ConvertTo-Json
  $attResult = Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $att
  Assert-True ($attResult.case.status -eq "attested") "complete evidence is attested by the designated attestor"

  $pkg = @{ released_by = "compliance-lead"; attestation_ref = "attestation://smoke"; idempotency_key = "smoke-comp-pkg-v1" } | ConvertTo-Json
  $pkgResult = Invoke-RestMethod -Method Post -Uri "$compBase/packages" -ContentType "application/json" -Body $pkg
  $immutability = $null
  try {
    $pkg2 = @{ released_by = "compliance-lead"; attestation_ref = "attestation://smoke"; idempotency_key = "smoke-comp-pkg2-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$compBase/packages" -ContentType "application/json" -Body $pkg2 | Out-Null
  } catch { $immutability = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($pkgResult.case.status -eq "released") "audit package releases after attestation"
  Assert-True ($immutability -eq 409) "released audit package is immutable (HTTP 409)"

  # Fleet mission flow
  $fleetBase = "$fleetAddr/v1/missions/mission-alpha-001"
  $start = @{ started_by = "ops-lead"; idempotency_key = "smoke-fleet-start-v1" } | ConvertTo-Json
  $startResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/start" -ContentType "application/json" -Body $start
  Assert-True ($startResult.mission.status -eq "running") "mission starts within its boundary"

  $boundaryDenied = $null
  try {
    $deviation = @{ position = "zone-omega"; status = "running"; idempotency_key = "smoke-fleet-tl-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$fleetBase/telemetry" -ContentType "application/json" -Body $deviation | Out-Null
  } catch { $boundaryDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($boundaryDenied -eq 403) "out-of-boundary telemetry is frozen (HTTP 403)"

  $inBounds = @{ position = "zone-alpha"; status = "running"; idempotency_key = "smoke-fleet-tl2-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$fleetBase/telemetry" -ContentType "application/json" -Body $inBounds | Out-Null

  $ex = @{ type = "obstacle"; detail = "rack-07 blocked"; raised_by = "fleet-runtime"; idempotency_key = "smoke-fleet-ex-v1" } | ConvertTo-Json
  $exResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/exceptions" -ContentType "application/json" -Body $ex
  Assert-True ($exResult.mission.status -eq "paused") "exception pauses the mission"

  $reviewDenied = $null
  try {
    $outsider = @{ reviewed_by = "outsider"; decision = "resume"; approval_ref = "approval://smoke"; idempotency_key = "smoke-fleet-rv-v1" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$fleetBase/reviews" -ContentType "application/json" -Body $outsider | Out-Null
  } catch { $reviewDenied = $_.Exception.Response.StatusCode.value__ }
  Assert-True ($reviewDenied -eq 403) "non-operator review is rejected (HTTP 403)"

  $review = @{ reviewed_by = "ops-lead"; decision = "resume"; approval_ref = "approval://smoke"; idempotency_key = "smoke-fleet-rv-v1" } | ConvertTo-Json
  $reviewResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/reviews" -ContentType "application/json" -Body $review
  Assert-True ($reviewResult.mission.status -eq "resumed") "operator review resumes the mission"

  $comp = @{ completed_by = "ops-lead"; idempotency_key = "smoke-fleet-cmp-v1" } | ConvertTo-Json
  $compResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/complete" -ContentType "application/json" -Body $comp
  Assert-True ($compResult.mission.status -eq "completed") "mission completes after review"

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
  Remove-Item "$env:TEMP\smoke-simulation-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-compliance-data.json" -ErrorAction SilentlyContinue
  Remove-Item "$env:TEMP\smoke-fleet-data.json" -ErrorAction SilentlyContinue
}
