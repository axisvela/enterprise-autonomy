param(
  [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$axisVelaHome = if ($env:AXISVELA_HOME) { $env:AXISVELA_HOME } else { (Resolve-Path (Join-Path $root "..\..\..")).Path }
$dataDir = Join-Path $root ".local-data"
$logDir = Join-Path $root ".local-logs"
New-Item -ItemType Directory -Force -Path $dataDir, $logDir | Out-Null
Get-Process nomivela, eidovelad, aegivela-api, limenora-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$psql = "D:\app\PostgreSQL\18\bin\psql.exe"
$createdb = "D:\app\PostgreSQL\18\bin\createdb.exe"
if (-not (Test-Path $psql)) { throw "psql not found at $psql" }
$env:PGPASSWORD = "postgres"

function Ensure-Database($name) {
  $exists = & $psql -h 127.0.0.1 -p 5433 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$name'"
  if ($exists.Trim() -ne "1") {
    & $createdb -h 127.0.0.1 -p 5433 -U postgres $name
    if ($LASTEXITCODE -ne 0) { throw "createdb $name failed" }
  }
}

function Build-Go($dir, $out, $pkg) {
  if ((Test-Path $out) -and -not $Rebuild) { return }
  $previous = $env:GOWORK
  $env:GOWORK = "off"
  Push-Location $dir
  try {
    go build -o $out $pkg
    if ($LASTEXITCODE -ne 0) { throw "go build $pkg failed" }
  } finally {
    Pop-Location
    $env:GOWORK = $previous
  }
}

foreach ($db in @("a2a_iam_nomivela", "a2a_iam_eidovela", "a2a_iam_aegivela", "a2a_iam_limenora")) {
  Ensure-Database $db
}

$nomivelaBin = Join-Path $dataDir "nomivela.exe"
$eidovelaBin = Join-Path $dataDir "eidovelad.exe"
$eidovelaMig = Join-Path $dataDir "eidovela-migrate.exe"
$aegivelaBin = Join-Path $dataDir "aegivela-api.exe"
$limenoraBin = Join-Path $dataDir "limenora-server.exe"

Build-Go (Join-Path $axisVelaHome "NOMIVELA\backend") $nomivelaBin "./cmd/nomivela"
Build-Go (Join-Path $axisVelaHome "EIDOVELA\backend") $eidovelaBin "./cmd/eidovelad"
Build-Go (Join-Path $axisVelaHome "EIDOVELA\backend") $eidovelaMig "./cmd/eidovela-migrate"
Build-Go (Join-Path $axisVelaHome "Aegivela\backend") $aegivelaBin "./cmd/aegivela-api"
Build-Go (Join-Path $axisVelaHome "LIMENORA\backend\go") $limenoraBin "./cmd/server-gateway"

$decisionKey = Join-Path $dataDir "decision.key"
$grantKey = Join-Path $dataDir "grant.key"
$workloadKey = Join-Path $dataDir "workload.key"
if (-not (Test-Path $decisionKey)) { & openssl genpkey -algorithm ed25519 -out $decisionKey; if ($LASTEXITCODE -ne 0) { throw "decision key generation failed" } }
if (-not (Test-Path $grantKey)) { & openssl genpkey -algorithm ed25519 -out $grantKey; if ($LASTEXITCODE -ne 0) { throw "grant key generation failed" } }
if (-not (Test-Path $workloadKey)) { & openssl genpkey -algorithm ed25519 -out $workloadKey; if ($LASTEXITCODE -ne 0) { throw "workload key generation failed" } }
$audienceFile = Join-Path $dataDir "audiences.json"
[IO.File]::WriteAllText($audienceFile, '{"audiences":[{"audience":"praxo-a2a"}]}', (New-Object Text.UTF8Encoding($false)))

$eidovelaDSN = "postgres://postgres:postgres@127.0.0.1:5433/a2a_iam_eidovela?sslmode=disable"
$env:EIDOVELA_DATABASE_URL = $eidovelaDSN
& $psql -h 127.0.0.1 -p 5433 -U postgres -d postgres -v ON_ERROR_STOP=1 -c "ALTER DATABASE a2a_iam_eidovela SET search_path TO eidovela, public" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "eidovela search_path setup failed" }
& $eidovelaMig -dir (Join-Path $axisVelaHome "EIDOVELA\backend\migrations")
if ($LASTEXITCODE -ne 0) { throw "eidovela migration failed" }

$aegivelaSchema = (& $psql -h 127.0.0.1 -p 5433 -U postgres -d a2a_iam_aegivela -tAc "SELECT to_regclass('public.agent_identities') IS NOT NULL").Trim()
if ($aegivelaSchema -ne "t") {
  Get-ChildItem (Join-Path $axisVelaHome "Aegivela\backend\deploy\postgres\migrations") -Filter *.up.sql |
    Sort-Object Name |
    ForEach-Object {
      & $psql -h 127.0.0.1 -p 5433 -U postgres -d a2a_iam_aegivela -v ON_ERROR_STOP=1 -f $_.FullName | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "aegivela migration $($_.Name) failed" }
    }
}

$nomivelaSchema = (& $psql -h 127.0.0.1 -p 5433 -U postgres -d a2a_iam_nomivela -tAc "SELECT to_regclass('public.schema_migrations') IS NOT NULL").Trim()
$env:NOMIVELA_DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5433/a2a_iam_nomivela?sslmode=disable"
$env:NOMIVELA_HTTP_PORT = "1956"
$env:NOMIVELA_MIGRATE = if ($nomivelaSchema -eq "t") { "false" } else { "true" }
$env:NOMIVELA_API_TOKENS = "dev-token"
Start-Process -FilePath $nomivelaBin -RedirectStandardOutput (Join-Path $logDir "nomivela.out.log") -RedirectStandardError (Join-Path $logDir "nomivela.err.log") -WindowStyle Hidden

$env:EIDOVELA_LISTEN_ADDR = "127.0.0.1:1966"
$env:EIDOVELA_ISSUER = "http://127.0.0.1:1966"
$env:EIDOVELA_NOMIVELA_URL = "http://127.0.0.1:1956"
$env:EIDOVELA_NOMIVELA_NAMESPACE = "https://registry.a2a-iam.test"
$env:EIDOVELA_NOMIVELA_TOKEN = "dev-token"
$env:EIDOVELA_NOMIVELA_CACHE_TTL = "0s"
$env:EIDOVELA_REQUIRE_DPOP = "1"
Start-Process -FilePath $eidovelaBin -RedirectStandardOutput (Join-Path $logDir "eidovela.out.log") -RedirectStandardError (Join-Path $logDir "eidovela.err.log") -WindowStyle Hidden

$env:DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5433/a2a_iam_aegivela?sslmode=disable"
$env:AEGIVELA_INTERNAL_AUTH_TOKEN = "dev-aegivela-token"
$env:AEGIVELA_LISTEN_ADDR = "127.0.0.1:1886"
$env:AEGIVELA_POLICY_DECISION_SIGNING_KEY_FILE = $decisionKey
$env:AEGIVELA_POLICY_DECISION_SIGNING_KEY_ID = "decision-1"
$env:AEGIVELA_POLICY_DECISION_ISSUER = "http://127.0.0.1:1886"
$env:AEGIVELA_EXECUTION_GRANT_SIGNING_KEY_FILE = $grantKey
$env:AEGIVELA_EXECUTION_GRANT_SIGNING_KEY_ID = "grant-1"
$env:AEGIVELA_EXECUTION_GRANT_ISSUER = "http://127.0.0.1:1886"
$env:AEGIVELA_WORKLOAD_ASSERTION_SIGNING_KEY_FILE = $workloadKey
$env:AEGIVELA_WORKLOAD_ASSERTION_KEY_ID = "workload-1"
$env:AEGIVELA_WORKLOAD_ASSERTION_ISSUER = "http://127.0.0.1:1886"
$env:AEGIVELA_GRANT_AUDIENCE_REGISTRY_FILE = $audienceFile
$env:AEGIVELA_IDENTITY_SOURCE = "eidovela"
$env:AEGIVELA_EIDOVELA_URL = "http://127.0.0.1:1966"
$env:AEGIVELA_EIDOVELA_NAMESPACE = "https://registry.a2a-iam.test"
$env:AEGIVELA_EIDOVELA_TENANT = "demo"
Start-Process -FilePath $aegivelaBin -RedirectStandardOutput (Join-Path $logDir "aegivela.out.log") -RedirectStandardError (Join-Path $logDir "aegivela.err.log") -WindowStyle Hidden

$env:DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5433/a2a_iam_limenora?sslmode=disable"
$env:GATEWAY_EIDOVELA_URL = "http://127.0.0.1:1966"
$env:GATEWAY_EIDOVELA_AUDIENCE = "praxo-a2a"
$env:GATEWAY_RESOURCE_PROOF_CARRIAGE = "request_header"
$env:GATEWAY_AGENT_TUNNEL_POLICY = "deny"
$env:GATEWAY_AGENT_EGRESS_REQUIRED = "true"
$env:GATEWAY_AEGIVELA_URL = "http://127.0.0.1:1886"
$env:GATEWAY_AEGIVELA_INTERNAL_TOKEN = "dev-aegivela-token"
$env:GATEWAY_AEGIVELA_TENANT = "demo"
$env:GATEWAY_AEGIVELA_AUDIENCE = "praxo-a2a"
$env:GATEWAY_AEGIVELA_ACTION = "connection:open"
$env:GATEWAY_AEGIVELA_SCOPE = "connection:open"
$env:GATEWAY_AEGIVELA_ASSERTION_SOURCE = "static"
$env:GATEWAY_ALLOWED_DESTINATIONS = "127.0.0.1"
Start-Process -FilePath $limenoraBin -RedirectStandardOutput (Join-Path $logDir "limenora.out.log") -RedirectStandardError (Join-Path $logDir "limenora.err.log") -WindowStyle Hidden

function Wait-Http($url, $seconds = 30) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    try {
      Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 $url | Out-Null
      return $true
    } catch {
      if ($_.Exception.Response) { return $true }
      Start-Sleep -Milliseconds 500
    }
  }
  return $false
}

$checks = @(
  @{ Name = "NOMIVELA"; URL = "http://127.0.0.1:1956/healthz" },
  @{ Name = "EIDOVELA"; URL = "http://127.0.0.1:1966/healthz" },
  @{ Name = "AEGIVELA"; URL = "http://127.0.0.1:1886/v1/policies" },
  @{ Name = "LIMENORA"; URL = "http://127.0.0.1:1897/healthz" }
)
$failed = @()
foreach ($check in $checks) {
  if (Wait-Http $check.URL) {
    Write-Host "$($check.Name) ready: $($check.URL)" -ForegroundColor Green
  } else {
    Write-Host "$($check.Name) not ready: $($check.URL)" -ForegroundColor Red
    $failed += $check.Name
  }
}
if ($failed.Count -gt 0) {
  Write-Host "Logs: $logDir" -ForegroundColor Yellow
  exit 1
}
Write-Host "A2A Agent IAM local stack ready." -ForegroundColor Green
