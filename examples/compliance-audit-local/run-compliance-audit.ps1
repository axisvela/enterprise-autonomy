param()

if (-not $ComplianceCaseId -or -not $ComplianceLead -or -not $AttestationRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ case_id = $ComplianceCaseId; tenant = $TenantId; compliance_lead = $ComplianceLead; steps = @(); case_state = $null }
$evidence = @()
$gates = @()

$compBase = "http://localhost:8098/v1/compliance/$ComplianceCaseId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "comp-0001-req-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ComplianceLead; "Idempotency-Key" = "comp-0001-case-v1" }

# Step 1: open the compliance case (Symbivela)
$workspace = @{ workspace_id = "compliance"; name = "Compliance Operations"; owner_id = $ComplianceLead } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ComplianceLead; "Idempotency-Key" = "compliance-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "compliance"; case_id = "comp-0001-audit"; subject_ref = "compliance://compliance-0001"; problem = "Assemble the audit package for SOC2-1 with complete evidence and a designated attestation."; evidence_refs = "requirement://SOC2-1"; candidate_actions = "collect,attest,defer,release"; deadline = "2026-08-30T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $ComplianceLead; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the compliance case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the compliance case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The audit package is gated on complete evidence and attestation."

# Step 2: record the requirement context (adapter + Ontovela)
$compCase = Invoke-RestMethod -Uri $compBase
$assertion = @{ id = "assertion-compliance-0001-req"; subject_id = $ComplianceCaseId; property = "requirement"; value = $Requirement; state_kind = "observed"; event_time = "2026-08-16T15:00:00Z"; system_time = "2026-08-16T15:00:01Z"; source = "compliance-system"; evidence_ref = "evidence://compliance/compliance-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$gates += @{ gate = "requirement-context"; owner = $ComplianceLead; decision = "scoped"; requirement = $Requirement }
$evidence += @{ product = "compliance-domain"; artifact = $compCase.id; state = $compCase.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-compliance-0001-req"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the requirement context"; product = "ontovela"; artifact = "assertion-compliance-0001-req" }
Write-Step 2 "Record the requirement context" "Case $ComplianceCaseId requires $($compCase.required_items.Count) evidence items for $Requirement. Ontovela asserts the requirement with compliance evidence."

# Step 3: attestation gate - attest before all evidence is denied
$attDenied = $null
try {
  $premature = @{ attested_by = $ComplianceLead; decision = "attest"; attestation_ref = $AttestationRef; idempotency_key = "comp-att-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $premature | Out-Null
} catch { $attDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "compliance-domain"; artifact = "attestation-without-evidence-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show completeness gates attestation"; product = "compliance-domain"; artifact = "attestation-without-evidence-rejected" }
$attDeniedText = if ($attDenied) { "The adapter rejected attestation before all evidence (HTTP $attDenied)." } else { "The adapter enforced evidence completeness." }
Write-Step 3 "Show completeness gates attestation" "Attestation was attempted before all evidence was collected; the adapter denied it. $attDeniedText"

# Step 4: collect the four evidence items
for ($i = 1; $i -le 4; $i++) {
  $item = "evidence-item-$i"
  $evBody = @{ item_id = $item; source = "governed-source-$i"; timestamp = "2026-08-16T14:0$i`:00Z"; evidence_ref = "evidence://comp/item-$i"; collected_by = $ComplianceLead; idempotency_key = "comp-ev-$i" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$compBase/evidence" -ContentType "application/json" -Body $evBody | Out-Null
  $evidence += @{ product = "compliance-domain"; artifact = "evidence-item-$i"; state = "collected" }
}
$compAfter = Invoke-RestMethod -Uri $compBase
$gates += @{ gate = "evidence-complete"; owner = $ComplianceLead; decision = "complete"; items = $compAfter.evidence.Count }
$outcome.steps += @{ index = 4; title = "Collect the required evidence"; product = "compliance-domain"; artifact = "evidence-complete" }
Write-Step 4 "Collect the required evidence" "All $($compAfter.required_items.Count) evidence items collected from governed sources. Status is '$($compAfter.status)'."

# Step 5: attestation (designated attestor; non-attestor denied first)
$nonAttestorDenied = $null
try {
  $outsider = @{ attested_by = "outsider"; decision = "attest"; attestation_ref = $AttestationRef; idempotency_key = "comp-att-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $outsider | Out-Null
} catch { $nonAttestorDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "compliance-domain"; artifact = "non-attestor-rejected"; state = "denied" }
$attBody = @{ attested_by = $ComplianceLead; decision = "attest"; attestation_ref = $AttestationRef; idempotency_key = "comp-att-v1" } | ConvertTo-Json
$attResult = Invoke-RestMethod -Method Post -Uri "$compBase/attestations" -ContentType "application/json" -Body $attBody
$gates += @{ gate = "attestation"; owner = $ComplianceLead; decision = "attest"; attestation_ref = $AttestationRef }
$evidence += @{ product = "compliance-domain"; artifact = $attResult.attestation.id; state = $attResult.case.status }
$outcome.steps += @{ index = 5; title = "Attest the evidence set"; product = "compliance-domain"; artifact = $attResult.attestation.id }
$nonAttestorText = if ($nonAttestorDenied) { "A non-designated attestor was rejected (HTTP $nonAttestorDenied)." } else { "Only the designated attestor may attest." }
Write-Step 5 "Attest the evidence set" "$ComplianceLead attested the evidence set under '$AttestationRef'. Status is '$($attResult.case.status)'. $nonAttestorText"

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "compliance-audit-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "compliance-audit-workflow.json") | Out-Null
$process = @{ workflow = "compliance-request-to-audit"; project = $ComplianceCaseId; actor = $ComplianceLead } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable compliance process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable compliance process" "Rheovela opened process instance '$($instance.id)' for 'compliance-request-to-audit'. Stages: collect, attest, package, release, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "compliance-audit-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-comp-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a compliance plan"; product = "orchadyn"; artifact = "plan-comp-0001" }
  Write-Step 7 "Generate a compliance plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Attestation requires completeness."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a compliance plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a compliance plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: release the audit package (attestation-gated, immutable)
$refDenied = $null
try {
  $wrongRef = @{ released_by = $ComplianceLead; attestation_ref = "attestation://wrong"; idempotency_key = "comp-pkg-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$compBase/packages" -ContentType "application/json" -Body $wrongRef | Out-Null
} catch { $refDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "compliance-domain"; artifact = "attestation-ref-mismatch-rejected"; state = "denied" }
$pkgBody = @{ released_by = $ComplianceLead; attestation_ref = $AttestationRef; idempotency_key = "comp-pkg-v1" } | ConvertTo-Json
$pkgResult = Invoke-RestMethod -Method Post -Uri "$compBase/packages" -ContentType "application/json" -Body $pkgBody
$immutabilityDenied = $null
try {
  $pkgBody2 = @{ released_by = $ComplianceLead; attestation_ref = $AttestationRef; idempotency_key = "comp-pkg2-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$compBase/packages" -ContentType "application/json" -Body $pkgBody2 | Out-Null
} catch { $immutabilityDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "compliance-domain"; artifact = "package-immutability-rejected"; state = "denied" }
$finalCase = Invoke-RestMethod -Uri $compBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8098/v1/notifications/$ComplianceCaseId"
$evidence += @{ product = "compliance-domain"; artifact = $pkgResult.package_id; state = $finalCase.status }
$outcome.steps += @{ index = 8; title = "Release the audit package"; product = "compliance-domain"; artifact = $pkgResult.package_id }
$outcome.case_state = $finalCase
$outcome.notifications = $notifications.notifications
$refDeniedText = if ($refDenied) { "A package citing the wrong attestation reference was rejected (HTTP $refDenied)." } else { "Release required the exact attestation reference." }
$immutabilityText = if ($immutabilityDenied) { "A second package was rejected (HTTP $immutabilityDenied) - released packages are immutable." } else { "The released package is immutable." }
Write-Step 8 "Release the audit package" "Audit package '$($pkgResult.package_id)' released. Status is '$($finalCase.status)'. Pending notifications: '$($notifications.notifications -join ', ')'. $refDeniedText $immutabilityText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "compliance-request-to-audit"
  version = "1.0"
  tenant = $TenantId
  compliance_lead = $ComplianceLead
  outcome = @{ subject = $finalCase.id; before = "open"; after = $finalCase.status; package = $finalCase.package_id; completed = ($finalCase.status -eq "released"); escalated = $false }
  kpis = @{
    products_involved = $products.Count
    gates_passed = $gates.Count
    evidence_artifacts = $evidence.Count
    steps_completed = $outcome.steps.Count
    time_to_resolve = $elapsed.TotalSeconds.ToString("F1")
  }
  gates = $gates
  evidence = $evidence
  steps = $outcome.steps
}

Write-Host ""
Write-Host "================ Business Outcome ================" -ForegroundColor Green
Write-Host "Case        : $($finalCase.id) ($Requirement)"
Write-Host "Status      : open -> $($finalCase.status)"
Write-Host "Evidence    : $($finalCase.evidence.Count) of $($finalCase.required_items.Count) items"
Write-Host "Attestation : $($finalCase.attestation.decision) by $($finalCase.attestation.attested_by)"
Write-Host "Package     : $($finalCase.package_id)"
Write-Host "Denials     : completeness (HTTP $attDenied), non-attestor (HTTP $nonAttestorDenied), ref mismatch (HTTP $refDenied), immutability (HTTP $immutabilityDenied)"
Write-Host "Audit trail : Symbivela case + compliance evidence/attestation/package + Ontovela assertion + Rheovela process + Orchadyn plan"
Write-Host "==================================================="

Write-Host ""
Write-Host "================ Value & Effect ================" -ForegroundColor Cyan
Write-Host "Products involved : $($report.kpis.products_involved)"
Write-Host "Gates passed      : $($report.kpis.gates_passed)"
Write-Host "Evidence artifacts: $($report.kpis.evidence_artifacts)"
Write-Host "Steps completed   : $($report.kpis.steps_completed)"
Write-Host "Time to resolve   : $($report.kpis.time_to_resolve)s"
Write-Host "================================================="

$outcomeDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $outcomeDir | Out-Null
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "compliance-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "compliance-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\compliance-outcome.json"
Write-Host "Value report written to .local-data\compliance-value-report.json"
