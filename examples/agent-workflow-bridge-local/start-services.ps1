param([switch]$RebuildAxond)
$ErrorActionPreference = "Stop"
if (-not $env:AXISROBO_HOME -or -not $env:AEGIVELA_DIR) { throw "Load local.env.ps1 before running this script." }

$root    = $PSScriptRoot
$dataDir = Join-Path $root ".local-data"
$logDir  = Join-Path $root ".local-logs"
$keyDir  = Join-Path $dataDir "keys"
New-Item -ItemType Directory -Force -Path $dataDir, $logDir, $keyDir | Out-Null

function Wait-Http($url, $seconds = 30) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 | Out-Null; return $true }
    catch {
      # A non-2xx HTTP response (e.g. 401 when Rheovela auth is enabled) still
      # means the listener is up; this is a liveness gate.
      if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -gt 0) { return $true }
      Start-Sleep -Milliseconds 500
    }
  }
  return $false
}

function Start-Logged($file, $argList, $extraEnv) {
  $name = [IO.Path]::GetFileNameWithoutExtension($file)
  $out = Join-Path $logDir "$name.out.log"
  $err = Join-Path $logDir "$name.err.log"
  # Start-Process inherits this session's environment; the caller sets $env:* first.
  # NOTE: do not name this parameter $args — that is PowerShell's automatic
  # variable and the argv would be dropped (the process then prints help).
  # PS 5.1 also rejects an empty -ArgumentList, so only pass it when non-empty.
  $params = @{ FilePath = $file; PassThru = $true; RedirectStandardOutput = $out; RedirectStandardError = $err }
  if ($argList) { $params.ArgumentList = $argList }
  $p = Start-Process @params
  Set-Content -Path (Join-Path $dataDir "$name.pid") -Value $p.Id
  return $p
}

# --- 1. dev signing keys -----------------------------------------------------
Push-Location (Join-Path $root "tools\genkeys")
try {
  $prev = $env:GOWORK; $env:GOWORK = "off"
  try { go run . $keyDir } finally { $env:GOWORK = $prev }
} finally { Pop-Location }

# --- 2. database + migrations ------------------------------------------------
$db = $env:AEGIVELA_DB
$migrate = Get-Command migrate -ErrorAction SilentlyContinue
$psql    = Get-Command psql -ErrorAction SilentlyContinue
if (-not $migrate -and -not $psql) {
  throw "Neither 'migrate' nor 'psql' is on PATH. Apply $env:AEGIVELA_DIR\backend\deploy\postgres\migrations to '$db' first (the schema needs CREATE EXTENSION age)."
}
if ($psql) {
  # Expected "already exists" notices go to stderr; under
  # $ErrorActionPreference=Stop PS 5.1 turns native stderr into a terminating
  # error, so run these best-effort calls with Continue.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & psql $env:FP1_ADMIN_DSN -c "CREATE DATABASE $db" 2>$null | Out-Null
    & psql ("postgres://postgres:postgres@localhost:5432/${db}?sslmode=disable") -c "CREATE EXTENSION IF NOT EXISTS age" 2>$null | Out-Null
  } finally { $ErrorActionPreference = $prevEap }
}
$dbURL = "postgres://postgres:postgres@localhost:5432/${db}?sslmode=disable"
if ($migrate) {
  & migrate -path (Join-Path $env:AEGIVELA_DIR "backend\deploy\postgres\migrations") -database $dbURL up
} else {
  Write-Output "[start-services] 'migrate' not found: assuming '$db' is already migrated (see README step 1)."
}

# --- 3. AEGIVELA ------------------------------------------------------------
$env:DATABASE_URL = $dbURL
$env:AEGIVELA_LISTEN_ADDR = $env:AEGIVELA_ADDR
$env:AEGIVELA_POLICY_DECISION_SIGNING_KEY_FILE = Join-Path $keyDir "policy-decision.pem"
$env:AEGIVELA_POLICY_DECISION_SIGNING_KEY_ID   = "dev-policy-decision"
$env:AEGIVELA_POLICY_DECISION_ISSUER           = $env:AEGIVELA_ISSUER
$env:AEGIVELA_EXECUTION_GRANT_SIGNING_KEY_FILE = Join-Path $keyDir "execution-grant.pem"
$env:AEGIVELA_EXECUTION_GRANT_SIGNING_KEY_ID   = "dev-execution-grant"
$env:AEGIVELA_EXECUTION_GRANT_ISSUER           = $env:AEGIVELA_ISSUER
$env:AEGIVELA_GRANT_AUDIENCE_REGISTRY_FILE     = Join-Path $keyDir "audiences.json"
$env:AEGIVELA_WORKLOAD_ASSERTION_SIGNING_KEY_FILE = Join-Path $keyDir "workload-assertion.pem"
$env:AEGIVELA_WORKLOAD_ASSERTION_KEY_ID           = "dev-workload-assertion"
$env:AEGIVELA_WORKLOAD_ASSERTION_ISSUER           = $env:AEGIVELA_ISSUER

$aegivelaBin = Join-Path $env:AEGIVELA_DIR "bin\aegivela-api"
# Windows builds carry a .exe suffix; PS cannot activate an extensionless PE.
if (Test-Path "$aegivelaBin.exe") { $aegivelaBin = "$aegivelaBin.exe" }
if (-not (Test-Path $aegivelaBin)) { throw "AEGIVELA binary not found: $aegivelaBin (build cmd/aegivela-api)" }
$aegivela = Start-Logged $aegivelaBin @() $null
if (-not (Wait-Http "http://127.0.0.1:1886/healthz")) { throw "AEGIVELA did not become healthy; see .local-logs" }
Write-Output "[start-services] AEGIVELA healthy"

# --- 4. workload binding ----------------------------------------------------
$authHeaders = @{
  'X-Aegivela-Internal-Token' = $env:AEGIVELA_INTERNAL_AUTH_TOKEN
  'X-Aegivela-Tenant-ID'      = $env:WORKLOAD_TENANT
  'X-Aegivela-Actor-ID'       = $env:WORKLOAD_SUBJECT
  'X-Aegivela-Authority-Root' = $env:WORKLOAD_ORG
}
$bindingBody = @{
  api_version       = 'aegivela.io/v1alpha1'
  subject_ref       = $env:WORKLOAD_SUBJECT
  organization_root = $env:WORKLOAD_ORG
  client_id         = $env:WORKLOAD_CLIENT
  workload_ref      = $env:WORKLOAD_REF
  evidence_ref      = 'evidence:dev-bridge-local'   # must carry the evidence: prefix
  trace_id          = '4bf92f3577b34da6a3ce929d0e0e4736'
}
$binding = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:1886/v1/workload-bindings' `
  -Headers $authHeaders -ContentType 'application/json' -Body ($bindingBody | ConvertTo-Json -Compress)
$env:AXON_WORKLOAD_BINDING_ID = $binding.BindingID
Write-Output "[start-services] workload binding $($binding.BindingID)"

# --- 5. Rheovela ------------------------------------------------------------
$env:RHEO_AUTH_JWKS     = 'http://127.0.0.1:1886/v1/workload-assertions/jwks'
$env:RHEO_AUTH_ISSUER   = $env:AEGIVELA_ISSUER
$env:RHEO_AUTH_AUDIENCE = $env:RHEOVELA_AUDIENCE
$rheoBin = Get-ChildItem (Join-Path $env:RHEOVELA_DIR "dist") -Filter "rheo-windows-amd64*" |
  Where-Object { $_.Name -notmatch 'SHA256' } | Select-Object -First 1 -ExpandProperty FullName
if (-not $rheoBin) {
  $rheoBin = Get-ChildItem (Join-Path $env:RHEOVELA_DIR "dist") -Filter "rheo*" |
    Where-Object { $_.Name -notmatch 'SHA256' } | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $rheoBin) { throw "No rheo binary under $env:RHEOVELA_DIR\dist" }
$rheo = Start-Logged $rheoBin @('serve', '--addr', $env:RHEOVELA_ADDR, '--db', (Join-Path $dataDir 'rheo.db')) $null
if (-not (Wait-Http "http://127.0.0.1:1876/api/v1/health")) { throw "Rheovela did not become healthy; see .local-logs" }
Write-Output "[start-services] Rheovela healthy"

# publish the E2E workflow (authenticated with a freshly minted assertion)
$issueBody = @{
  api_version       = 'aegivela.io/v1alpha1'
  subject_ref       = $env:WORKLOAD_SUBJECT
  organization_root = $env:WORKLOAD_ORG
  binding_id        = $binding.BindingID
  client_id         = $env:WORKLOAD_CLIENT
  workload_ref      = $env:WORKLOAD_REF
  audience          = $env:RHEOVELA_AUDIENCE
  expires_at        = (Get-Date).ToUniversalTime().AddMinutes(4).ToString('o')
  trace_id          = '4bf92f3577b34da6a3ce929d0e0e4736'
}
$assertion = (Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:1886/v1/workload-assertions/issue' `
  -Headers $authHeaders -ContentType 'application/json' -Body ($issueBody | ConvertTo-Json -Compress)).workload_assertion
Invoke-WebRequest -Method Post -Uri 'http://127.0.0.1:1876/api/v1/workflows' `
  -Headers @{ Authorization = "Bearer $assertion" } -ContentType 'application/json' `
  -InFile $env:WORKFLOW_FILE -UseBasicParsing | Out-Null
Write-Output "[start-services] published workflow $env:WORKFLOW_ID"

# --- 6. axond ---------------------------------------------------------------
$axondBin = Join-Path $dataDir "axond.exe"
if ($RebuildAxond -or -not (Test-Path $axondBin)) {
  Push-Location $env:PRAXOVELA_DIR
  try { go build -o $axondBin ./packages/axon-core/cmd/axond } finally { Pop-Location }
}
$env:USERPROFILE = Join-Path $dataDir "axond-home"
$env:PRAXOVELA_HOME = Join-Path $env:USERPROFILE "prax"
New-Item -ItemType Directory -Force -Path $env:USERPROFILE, $env:PRAXOVELA_HOME | Out-Null
$env:AXON_PORT = $env:AXOND_PORT
$env:AXON_RHEOVELA_URL      = 'http://127.0.0.1:1876'
$env:AXON_RHEOVELA_AUDIENCE = $env:RHEOVELA_AUDIENCE
$env:AXON_AEGIVELA_URL      = 'http://127.0.0.1:1886'
$env:AXON_AEGIVELA_TOKEN    = $env:AEGIVELA_INTERNAL_AUTH_TOKEN
$env:AXON_AEGIVELA_TENANT_ID = $env:WORKLOAD_TENANT
$env:AXON_WORKLOAD_CLIENT_ID    = $env:WORKLOAD_CLIENT
$env:AXON_WORKLOAD_REF          = $env:WORKLOAD_REF
$env:AXON_WORKLOAD_SUBJECT_REF  = $env:WORKLOAD_SUBJECT
$env:AXON_WORKLOAD_ORG_ROOT     = $env:WORKLOAD_ORG

$axond = Start-Process -FilePath $axondBin -WorkingDirectory $env:USERPROFILE -PassThru `
  -RedirectStandardOutput (Join-Path $logDir 'axond.out.log') -RedirectStandardError (Join-Path $logDir 'axond.err.log')
Set-Content -Path (Join-Path $dataDir 'axond.pid') -Value $axond.Id
if (-not (Wait-Http ("http://127.0.0.1:{0}/health" -f $env:AXON_PORT))) { throw "axond did not become healthy; see .local-logs\axond.err.log" }
if (-not (Select-String -Path (Join-Path $logDir 'axond.err.log') -Pattern 'Orchestrator: Rheovela' -Quiet)) {
  throw "axond started without the Rheovela orchestrator (assertion minting failed?); see .local-logs\axond.err.log"
}
Write-Output "[start-services] axond healthy with the Rheovela orchestrator wired"
