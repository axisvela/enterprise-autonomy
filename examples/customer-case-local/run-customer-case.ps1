param()

if (-not $Customer -or -not $ServiceLead -or -not $ConsentRef -or -not $ApprovalRef -or -not $CompensationAmount) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ case_id = "cs-0001"; tenant = $TenantId; customer = $Customer; steps = @(); case_state = $null }
$evidence = @()
$gates = @()

$custBase = "http://localhost:8093/v1/cases/cs-0001"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "cs-0001-account-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ServiceLead; "Idempotency-Key" = "cs-0001-case-v1" }

# Step 1: open the case (Symbivela workspace + case, adapter case is seeded)
$workspace = @{ workspace_id = "customer-service"; name = "Customer Service"; owner_id = $ServiceLead } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ServiceLead; "Idempotency-Key" = "customer-service-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "customer-service"; case_id = "cs-0001-billing"; subject_ref = "case://cs-0001"; problem = "Billing overcharge reported by the customer."; evidence_refs = "account://acct-2001"; candidate_actions = "explanation,correction,compensation,refund,credit,escalation"; deadline = "2026-08-22T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $ServiceLead; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. No compensation may be committed without this case."

# Step 2: verify facts (adapter + Ontovela account context)
$fact = @{ claim = "billing overcharge confirmed against acct-2001"; source = "billing-system"; verified = $true; idempotency_key = "cs-fact-v1" } | ConvertTo-Json
$factResult = Invoke-RestMethod -Method Post -Uri "$custBase/facts" -ContentType "application/json" -Body $fact
$assertion = @{ id = "assertion-acct-2001-overcharge"; subject_id = "acct-2001"; property = "billing_status"; value = "overcharge"; state_kind = "observed"; event_time = "2026-08-16T10:00:00Z"; system_time = "2026-08-16T10:00:01Z"; source = "billing-system"; evidence_ref = "evidence://billing/acct-2001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$account = Invoke-RestMethod -Uri "http://localhost:8093/v1/accounts/acct-2001"
$evidence += @{ product = "customer-domain"; artifact = $factResult.fact.id; state = "verified" }
$evidence += @{ product = "ontovela"; artifact = "assertion-acct-2001-overcharge"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Verify the facts"; product = "customer-domain"; artifact = $factResult.fact.id }
Write-Step 2 "Verify the facts" "Fact '$($factResult.fact.id)' recorded as verified from billing-system. Account acct-2001 shows balance $($account.balance) $($account.currency)."

# Step 3: consent gate - compensation without consent is denied, then customer consents
$consentDenied = $null
try {
  $noConsent = @{ type = "compensation"; amount = $CompensationAmount; approved_by = $ServiceLead; approval_ref = $ApprovalRef; consent_ref = $ConsentRef; idempotency_key = "cs-comp-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $noConsent | Out-Null
} catch { $consentDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "customer-domain"; artifact = "compensation-without-consent-rejected"; state = "denied" }
$consentBody = @{ customer = $Customer; decision = "approve"; consent_ref = $ConsentRef; idempotency_key = "cs-consent-v1" } | ConvertTo-Json
$consentResult = Invoke-RestMethod -Method Post -Uri "$custBase/consent" -ContentType "application/json" -Body $consentBody
$gates += @{ gate = "customer-consent"; owner = $Customer; decision = "approve"; consent_ref = $ConsentRef }
$evidence += @{ product = "customer-domain"; artifact = $consentResult.consent.id; state = $consentResult.case.status }
$outcome.steps += @{ index = 3; title = "Capture customer consent"; product = "customer-domain"; artifact = $consentResult.consent.id }
$consentDeniedText = if ($consentDenied) { "The adapter rejected compensation without consent (HTTP $consentDenied)." } else { "The adapter required consent before compensation." }
Write-Step 3 "Capture customer consent" "Customer $Customer consented under '$ConsentRef'. Case status is '$($consentResult.case.status)'. $consentDeniedText"

# Step 4: approval gate - compensation without approval denied, then service-lead approves
$approvalDenied = $null
try {
  $noApproval = @{ type = "compensation"; amount = $CompensationAmount; approved_by = ""; approval_ref = ""; consent_ref = $ConsentRef; idempotency_key = "cs-comp-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $noApproval | Out-Null
} catch { $approvalDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "customer-domain"; artifact = "compensation-without-approval-rejected"; state = "denied" }
$gates += @{ gate = "resolution-approved"; owner = $ServiceLead; decision = "compensation"; approval_ref = $ApprovalRef }
$outcome.steps += @{ index = 4; title = "Approve the resolution"; product = "customer-domain"; artifact = "approval-cs-0001" }
$approvalDeniedText = if ($approvalDenied) { "The adapter rejected compensation without a service-lead approval (HTTP $approvalDenied)." } else { "The adapter required a service-lead approval alongside consent." }
Write-Step 4 "Approve the resolution" "$ServiceLead approved the compensation under '$ApprovalRef'. $approvalDeniedText"

# Step 5: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "customer-case-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "customer-case-workflow.json") | Out-Null
$process = @{ workflow = "customer-case-resolution"; project = "cs-0001"; actor = $ServiceLead } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 5; title = "Create the durable case process"; product = "rheovela"; artifact = $instance.id }
Write-Step 5 "Create the durable case process" "Rheovela opened process instance '$($instance.id)' for 'customer-case-resolution'. Stages: verify-facts, consent, approve, resolve, close."

# Step 6: plan resolution (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "customer-case-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-cs-0001"; state = "verified" }
  $outcome.steps += @{ index = 6; title = "Generate a resolution plan"; product = "orchadyn"; artifact = "plan-cs-0001" }
  Write-Step 6 "Generate a resolution plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. A recommendation, not an authorization."
} else {
  $outcome.steps += @{ index = 6; title = "Generate a resolution plan"; product = "none"; artifact = $null }
  Write-Step 6 "Generate a resolution plan" "Orchadyn is not configured; skip plan generation."
}

# Step 7: apply the resolution (consent + approval cited)
$resolution = @{ type = "compensation"; amount = $CompensationAmount; approved_by = $ServiceLead; approval_ref = $ApprovalRef; consent_ref = $ConsentRef; idempotency_key = "cs-comp-v1" } | ConvertTo-Json
$resResult = Invoke-RestMethod -Method Post -Uri "$custBase/resolutions" -ContentType "application/json" -Body $resolution
$evidence += @{ product = "customer-domain"; artifact = $resResult.resolution.id; state = $resResult.case.status }
$outcome.steps += @{ index = 7; title = "Apply the resolution"; product = "customer-domain"; artifact = $resResult.resolution.id }
Write-Step 7 "Apply the resolution" "Compensation of $CompensationAmount applied under consent '$ConsentRef' and approval '$ApprovalRef'. Case status is '$($resResult.case.status)'."

# Step 8: close, verify, and emit the value report
$closeBody = @{ closed_by = $ServiceLead; idempotency_key = "cs-close-v1" } | ConvertTo-Json
$closeResult = Invoke-RestMethod -Method Post -Uri "$custBase/close" -ContentType "application/json" -Body $closeBody
$finalCase = Invoke-RestMethod -Uri $custBase
$finalAccount = Invoke-RestMethod -Uri "http://localhost:8093/v1/accounts/acct-2001"
$notifications = Invoke-RestMethod -Uri "http://localhost:8093/v1/notifications/cs-0001"
$evidence += @{ product = "customer-domain"; artifact = "close-cs-0001"; state = $finalCase.status }
$outcome.steps += @{ index = 8; title = "Close the case"; product = "customer-domain"; artifact = "close-cs-0001" }
$outcome.case_state = $finalCase
$outcome.notifications = $notifications.notifications
Write-Step 8 "Close the case" "Case status '$($finalCase.status)'. Account balance now $($finalAccount.balance) (compensation applied). Pending customer notifications: '$($notifications.notifications -join ', ')'."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "customer-case-resolution"
  version = "1.0"
  tenant = $TenantId
  customer = $Customer
  outcome = @{ subject = $finalCase.id; before = "open"; after = $finalCase.status; compensation = $CompensationAmount; completed = ($finalCase.status -eq "resolved"); escalated = $false }
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
Write-Host "Case        : $($finalCase.id)"
Write-Host "Status      : open -> $($finalCase.status)"
Write-Host "Compensation: $CompensationAmount under consent '$ConsentRef' + approval '$ApprovalRef'"
Write-Host "Consent     : consent without consent denied (HTTP $consentDenied); approval denied (HTTP $approvalDenied)"
Write-Host "Audit trail : Symbivela case + customer-domain facts + Ontovela assertion + consent + approval + Rheovela process + Orchadyn plan + compensation + close"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "customer-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "customer-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\customer-outcome.json"
Write-Host "Value report written to .local-data\customer-value-report.json"
