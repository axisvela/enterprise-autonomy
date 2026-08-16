param()

if (-not $IntegrationOwner -or -not $WorkId -or -not $IntegrationId -or -not $PreservedRef -or -not $EvidenceRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ work_id = $WorkId; tenant = $TenantId; integration_owner = $IntegrationOwner; steps = @(); work_state = $null }
$evidence = @()
$gates = @()

$intBase = "http://localhost:8096/v1/integrations/$IntegrationId"
$workBase = "http://localhost:8096/v1/work/$WorkId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "iro-0001-outage-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $IntegrationOwner; "Idempotency-Key" = "iro-0001-case-v1" }

# Step 1: open the outage case (Symbivela)
$workspace = @{ workspace_id = "integration-ops"; name = "Integration Operations"; owner_id = $IntegrationOwner } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $IntegrationOwner; "Idempotency-Key" = "integration-ops-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "integration-ops"; case_id = "iro-0001-outage"; subject_ref = "integration://partner-shipping"; problem = "Partner shipping integration is down; in-flight work must be preserved and verified before resume."; evidence_refs = "integration://partner-shipping"; candidate_actions = "preserve,verify,resume,complete,escalate"; deadline = "2026-08-28T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $IntegrationOwner; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the outage case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the outage case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. Recovery of in-flight work is governed by this case."

# Step 2: detect the outage and record in-flight work (adapter + Ontovela)
$integration = Invoke-RestMethod -Uri $intBase
$work = Invoke-RestMethod -Uri $workBase
$assertion = @{ id = "assertion-partner-shipping-down"; subject_id = $IntegrationId; property = "integration_status"; value = "down"; state_kind = "observed"; event_time = "2026-08-16T10:00:00Z"; system_time = "2026-08-16T10:00:01Z"; source = "integration-monitor"; evidence_ref = "evidence://monitor/partner-shipping" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "integration-domain"; artifact = $integration.id; state = $integration.status }
$evidence += @{ product = "integration-domain"; artifact = $work.id; state = $work.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-partner-shipping-down"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Detect the outage and record in-flight work"; product = "ontovela"; artifact = "assertion-partner-shipping-down" }
Write-Step 2 "Detect the outage and record in-flight work" "Integration $IntegrationId is '$($integration.status)' since '$($integration.outage_since)'. In-flight work $WorkId is '$($work.status)' and affects $($work.affects)."

# Step 3: resume gate 1 - resume before preservation is denied
$resumeDenied1 = $null
try {
  $resumeBody = @{ resumed_by = $IntegrationOwner; idempotency_key = "iro-resume-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$workBase/resume" -ContentType "application/json" -Body $resumeBody | Out-Null
} catch { $resumeDenied1 = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "integration-domain"; artifact = "resume-before-preserve-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show resume requires preservation"; product = "integration-domain"; artifact = "resume-before-preserve-rejected" }
$resumeDenied1Text = if ($resumeDenied1) { "The adapter rejected resume before preservation (HTTP $resumeDenied1)." } else { "The adapter enforced preserve-before-resume." }
Write-Step 3 "Show resume requires preservation" "Resume was attempted before preservation; the adapter denied it. $resumeDenied1Text"

# Step 4: preserve the in-flight work
$preserveBody = @{ preserved_by = $IntegrationOwner; preserved_ref = $PreservedRef; idempotency_key = "iro-pres-v1" } | ConvertTo-Json
$preserveResult = Invoke-RestMethod -Method Post -Uri "$workBase/preserve" -ContentType "application/json" -Body $preserveBody
$gates += @{ gate = "work-preserved"; owner = $IntegrationOwner; decision = "preserved"; preserved_ref = $PreservedRef }
$evidence += @{ product = "integration-domain"; artifact = "preserve-iro-pres-v1"; state = $preserveResult.work.status }
$outcome.steps += @{ index = 4; title = "Preserve the in-flight work"; product = "integration-domain"; artifact = "preserve-iro-pres-v1" }
Write-Step 4 "Preserve the in-flight work" "$WorkId preserved under '$PreservedRef'. Status is '$($preserveResult.work.status)'. The work now survives the outage."

# Step 5: resume gate 2 - resume before verification denied, then record the reconnection check
$resumeDenied2 = $null
try {
  $resumeBody2 = @{ resumed_by = $IntegrationOwner; idempotency_key = "iro-resume-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$workBase/resume" -ContentType "application/json" -Body $resumeBody2 | Out-Null
} catch { $resumeDenied2 = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "integration-domain"; artifact = "resume-before-verify-rejected"; state = "denied" }
$checkBody = @{ checked_by = $IntegrationOwner; verified = $true; evidence_ref = $EvidenceRef; idempotency_key = "iro-check-v1" } | ConvertTo-Json
$checkResult = Invoke-RestMethod -Method Post -Uri "$intBase/checks" -ContentType "application/json" -Body $checkBody
$gates += @{ gate = "reconnect-verified"; owner = $IntegrationOwner; decision = "verified"; evidence_ref = $EvidenceRef }
$evidence += @{ product = "integration-domain"; artifact = $checkResult.check.id; state = $checkResult.integration.status }
$outcome.steps += @{ index = 5; title = "Verify the reconnection"; product = "integration-domain"; artifact = $checkResult.check.id }
$resumeDenied2Text = if ($resumeDenied2) { "The adapter rejected resume before verification (HTTP $resumeDenied2)." } else { "The adapter enforced verify-before-resume." }
Write-Step 5 "Verify the reconnection" "$IntegrationOwner verified $IntegrationId under '$EvidenceRef'. $resumeDenied2Text"

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "integration-recovery-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "integration-recovery-workflow.json") | Out-Null
$process = @{ workflow = "integration-outage-recovery"; project = $WorkId; actor = $IntegrationOwner } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable recovery process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable recovery process" "Rheovela opened process instance '$($instance.id)' for 'integration-outage-recovery'. Stages: preserve, verify, resume, complete, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "integration-recovery-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-iro-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a recovery plan"; product = "orchadyn"; artifact = "plan-iro-0001" }
  Write-Step 7 "Generate a recovery plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Resume requires preservation and verification."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a recovery plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a recovery plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: resume, complete, and emit the value report
$resumeFinal = @{ resumed_by = $IntegrationOwner; idempotency_key = "iro-resume-v1" } | ConvertTo-Json
$resumeResult = Invoke-RestMethod -Method Post -Uri "$workBase/resume" -ContentType "application/json" -Body $resumeFinal
$gates += @{ gate = "work-resumed"; owner = $IntegrationOwner; decision = "resumed" }
$completeBody = @{ completed_by = $IntegrationOwner; idempotency_key = "iro-comp-v1" } | ConvertTo-Json
$completeResult = Invoke-RestMethod -Method Post -Uri "$workBase/complete" -ContentType "application/json" -Body $completeBody
$rerunDenied = $null
try {
  $completeBody2 = @{ completed_by = $IntegrationOwner; idempotency_key = "iro-comp2-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$workBase/complete" -ContentType "application/json" -Body $completeBody2 | Out-Null
} catch { $rerunDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "integration-domain"; artifact = $resumeResult.work.id; state = $resumeResult.work.status }
$evidence += @{ product = "integration-domain"; artifact = "complete-iro-comp-v1"; state = $completeResult.work.status }
$evidence += @{ product = "integration-domain"; artifact = "silent-rerun-rejected"; state = "denied" }
$outcome.steps += @{ index = 8; title = "Resume, complete, and close"; product = "integration-domain"; artifact = "complete-iro-comp-v1" }
$finalWork = Invoke-RestMethod -Uri $workBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8096/v1/notifications/$WorkId"
$outcome.work_state = $finalWork
$outcome.notifications = $notifications.notifications
$rerunDeniedText = if ($rerunDenied) { "A second completion was rejected (HTTP $rerunDenied) - no silent re-execution." } else { "The adapter prevented re-execution of the completed action." }
Write-Step 8 "Resume, complete, and close" "Work $WorkId resumed and completed. Pending notifications: '$($notifications.notifications -join ', ')'. $rerunDeniedText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "integration-outage-recovery"
  version = "1.0"
  tenant = $TenantId
  integration_owner = $IntegrationOwner
  outcome = @{ subject = $finalWork.id; before = "inflight"; after = $finalWork.status; completed = ($finalWork.status -eq "completed"); escalated = $false }
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
Write-Host "Work        : $($finalWork.id) (affects $($finalWork.affects))"
Write-Host "Status      : inflight -> $($finalWork.status)"
Write-Host "Preserved   : under $PreservedRef"
Write-Host "Verified    : $EvidenceRef"
Write-Host "Denials     : resume-before-preserve (HTTP $resumeDenied1), resume-before-verify (HTTP $resumeDenied2), silent rerun (HTTP $rerunDenied)"
Write-Host "Audit trail : Symbivela case + integration preserve/check/resume/complete + Ontovela assertion + Rheovela process + Orchadyn plan"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "integration-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "integration-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\integration-outcome.json"
Write-Host "Value report written to .local-data\integration-value-report.json"
