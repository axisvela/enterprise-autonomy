param(
  [string]$AgentCredential = "limenora-a2a-demo",
  [string]$BackendToken = "order-token",
  [int]$Port = 1898,
  [int]$BackendPort = 18091,
  [switch]$Authority,
  [string]$Audience = "praxo-a2a",
  [string]$AegivelaURL = "http://127.0.0.1:1886",
  [string]$AegivelaToken = "dev-aegivela-token",
  [string]$Tenant = "demo",
  [string]$AgentID = "db18dbd9-65f1-470c-9539-93a394d242f5",
  [string]$BindingID = "MuA-uiLtANWocJ2aq_D8dg",
  [string]$ClientID = "google-adk",
  [string]$WorkloadRef = "workload-adk-1"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$axisVelaHome = if ($env:AXISVELA_HOME) { $env:AXISVELA_HOME } else { (Resolve-Path (Join-Path $root "..\..\..")).Path }
$dataDir = Join-Path $root ".local-data"
$logDir = Join-Path $root ".local-logs"
$example = Join-Path $root "..\a2a-adk-order-cancellation"
$serverExe = Join-Path $dataDir "praxo-a2a-server.exe"
$clientExe = Join-Path $dataDir "adk-gateway-client.exe"
$gatewayExe = Join-Path $dataDir "limenora-server.exe"
$bindingFile = Join-Path $dataDir "limenora-a2a-bindings.json"
$routeFile = Join-Path $dataDir "limenora-a2a-routes.json"
$serverProc = $null
$gatewayProc = $null

New-Item -ItemType Directory -Force -Path $dataDir, $logDir | Out-Null
if (-not (Test-Path $gatewayExe)) { throw "LIMENORA binary not found: $gatewayExe" }
if (-not (Get-NetTCPConnection -LocalPort 1897 -State Listen -ErrorAction SilentlyContinue)) {
  throw "local stack is not running; start it with .\start-services.ps1"
}
foreach ($candidatePort in @($Port, $BackendPort)) {
  if (Get-NetTCPConnection -LocalPort $candidatePort -State Listen -ErrorAction SilentlyContinue) {
    throw "port $candidatePort is already in use"
  }
}

function Build-Go($dir, $out, $pkg) {
  $previous = $env:GOWORK
  Push-Location $dir
  try {
    $env:GOWORK = "off"
    go build -o $out $pkg
    if ($LASTEXITCODE -ne 0) { throw "go build $pkg failed" }
  } finally {
    Pop-Location
    $env:GOWORK = $previous
  }
}

Build-Go $example $serverExe "./cmd/praxo-server"
Build-Go $example $clientExe "./cmd/adk-client"

function Set-GatewayPolicy([string]$outcome) {
  $version = "v-" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $request = @{
    policy_id = "aegivela-gateway-connect"
    version = $version
    rules = @(@{ action = "connection:open"; outcome = $outcome; scope = @("connection:open") })
    activated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
  } | ConvertTo-Json -Depth 8 -Compress
  Invoke-RestMethod -Method Post -Uri "$AegivelaURL/v1/policies" -Headers $aegivelaHeaders -ContentType "application/json" -Body $request -TimeoutSec 10 | Out-Null
  Start-Sleep -Milliseconds 1100
}

$aegivelaHeaders = @{
  "X-Aegivela-Internal-Token" = $AegivelaToken
  "X-Aegivela-Tenant-ID" = $Tenant
  "X-Aegivela-Actor-ID" = "agent_google_adk_checkout"
  "X-Aegivela-Authority-Root" = "root:demo"
}
if ($Authority) {
  $assertionRequest = @{
    api_version = "aegivela.io/v1alpha1"
    subject_ref = "agent_google_adk_checkout"
    organization_root = "root:demo"
    binding_id = $BindingID
    client_id = $ClientID
    workload_ref = $WorkloadRef
    audience = $Audience
    expires_at = (Get-Date).ToUniversalTime().AddMinutes(5).ToString("yyyy-MM-ddTHH:mm:ssZ")
    trace_id = "trace-limenora-a2a-authority"
  } | ConvertTo-Json -Compress
  $AgentCredential = (Invoke-RestMethod -Method Post -Uri "$AegivelaURL/v1/workload-assertions/issue" -Headers $aegivelaHeaders -ContentType "application/json" -Body $assertionRequest -TimeoutSec 10).workload_assertion
  if (-not $AgentCredential) { throw "AEGIVELA returned an empty workload assertion" }
  Set-GatewayPolicy "allow"
}

$sha = [System.Security.Cryptography.SHA256]::Create()
$hash = ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($AgentCredential)) | ForEach-Object { $_.ToString("x2") }) -join ""
$bindingRecord = @{
  agent_ref = "agent_google_adk_checkout"
  agent_class = "service"
  identity_type = "autonomous"
  identity_mode = "native"
  authority = "limenora"
  agent_epoch = 4
  identity_epoch = 3
  token_hash = $hash
  audience = if ($Authority) { $Audience } else { "a2a-demo" }
  status = "active"
  issued_at = (Get-Date).ToUniversalTime().ToString("o")
}
if ($Authority) { $bindingRecord.agent_id = $AgentID }
$binding = @{ $hash = $bindingRecord }
$route = @(
  @{
    name = "a2a-order"
    path_prefix = "/a2a"
    backend = "http://127.0.0.1:$BackendPort"
    audience = if ($Authority) { $Audience } else { "a2a-demo" }
    require_agent = $true
    injection = @(
      @{
        id = "backend-bearer"
        source = "vault"
        location = "header"
        name = "Authorization"
        value = "Bearer $BackendToken"
      }
    )
  }
)
[IO.File]::WriteAllText($bindingFile, ($binding | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($routeFile, (ConvertTo-Json -InputObject $route -Depth 6), (New-Object Text.UTF8Encoding($false)))

$env:PRAXO_A2A_TOKEN = $BackendToken
$env:PRAXO_A2A_CARD_BASE = "http://127.0.0.1:$Port/a2a"
$serverProc = Start-Process -FilePath $serverExe -ArgumentList @("-addr", "127.0.0.1:$BackendPort") -PassThru -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $logDir "praxo-a2a-gateway.out.log") -RedirectStandardError (Join-Path $logDir "praxo-a2a-gateway.err.log")

$env:DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5433/a2a_iam_limenora?sslmode=disable"
$env:GATEWAY_AGENT_BINDINGS = $bindingFile
$env:GATEWAY_REVERSE_INGRESS_CONFIG = $routeFile
$env:GATEWAY_ALLOWED_DESTINATIONS = "127.0.0.1"
if ($Authority) {
  $env:GATEWAY_AEGIVELA_URL = $AegivelaURL
  $env:GATEWAY_AEGIVELA_INTERNAL_TOKEN = $AegivelaToken
  $env:GATEWAY_AEGIVELA_TENANT = $Tenant
  $env:GATEWAY_AEGIVELA_MODE = "service_agent_api"
  $env:GATEWAY_AEGIVELA_ACTION = "connection:open"
  $env:GATEWAY_AEGIVELA_SCOPE = "connection:open"
  $env:GATEWAY_AEGIVELA_AUDIENCE = $Audience
  $env:GATEWAY_AEGIVELA_ASSERTION_SOURCE = "federated"
} else {
  $env:GATEWAY_AEGIVELA_URL = ""
}
$gatewayProc = Start-Process -FilePath $gatewayExe -ArgumentList @("--port", "$Port") -PassThru -WindowStyle Hidden `
  -RedirectStandardOutput (Join-Path $logDir "limenora-a2a.out.log") -RedirectStandardError (Join-Path $logDir "limenora-a2a.err.log")

try {
  $deadline = (Get-Date).AddSeconds(20)
  while ((Get-Date) -lt $deadline) {
    try {
      $gateway = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/healthz" -TimeoutSec 1).StatusCode
      $backend = (Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$BackendPort/.well-known/agent-card.json" -TimeoutSec 1).StatusCode
      if ($gateway -eq 200 -and $backend -eq 200) { break }
    } catch {
      Start-Sleep -Milliseconds 250
    }
  }
  if ((Get-Date) -ge $deadline) { throw "gateway or backend did not become ready" }

  & $clientExe -card "http://127.0.0.1:$Port/a2a" -agent-credential $AgentCredential -prompt "Cancel order-1001"
  if ($LASTEXITCODE -ne 0) { throw "ADK client failed" }

  if ($Authority) {
    Set-GatewayPolicy "deny"
    $denied = $false
    try {
      Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/a2a" -Headers @{"X-LIMENORA-Agent-Credential" = $AgentCredential} -TimeoutSec 10 | Out-Null
    } catch {
      $denied = ([int]$_.Exception.Response.StatusCode -eq 403)
    } finally {
      Set-GatewayPolicy "allow"
    }
    if (-not $denied) { throw "reverse ingress did not enforce the AEGIVELA deny decision" }
    Write-Output "authority deny enforced"
  }
} finally {
  if ($gatewayProc -and -not $gatewayProc.HasExited) { Stop-Process -Id $gatewayProc.Id -Force -ErrorAction SilentlyContinue }
  if ($serverProc -and -not $serverProc.HasExited) { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue }
}
