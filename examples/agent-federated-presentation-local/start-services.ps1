param([switch]$Rebuild)

$ErrorActionPreference = "Stop"
if (-not $AxisRoboHome -or -not $env:FP1_ADMIN_DSN) { throw "Load local.env.ps1 before running this script." }

$logDir = Join-Path $PSScriptRoot ".local-logs"
$dataDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $logDir, $dataDir | Out-Null

# Build-Go builds the binary, but skips when it already exists unless -Rebuild is
# passed: rebuilding the three product binaries on every start is the dominant
# startup cost. Pass -Rebuild after changing product source.
function Build-Go($dir, $out, $pkg) {
  if ((Test-Path $out) -and -not $Rebuild) { Write-Output "[start-services] skip build $([IO.Path]::GetFileName($out)) (exists; use -Rebuild to force)"; return }
  $prev = $env:GOWORK
  $env:GOWORK = "off"
  Push-Location $dir
  try { go build -o $out $pkg } finally { Pop-Location; $env:GOWORK = $prev }
}

$nomivelaBin = Join-Path $dataDir "nomivela.exe"
$eidovelaBin = Join-Path $dataDir "eidovelad.exe"
$eidovelaMig = Join-Path $dataDir "eidovela-migrate.exe"
$limenoraBin = Join-Path $dataDir "limenora-server.exe"
Build-Go (Join-Path $AxisRoboHome "NOMIVELA\backend") $nomivelaBin "./cmd/nomivela"
Build-Go (Join-Path $AxisRoboHome "EIDOVELA\backend") $eidovelaBin "./cmd/eidovelad"
Build-Go (Join-Path $AxisRoboHome "EIDOVELA\backend") $eidovelaMig "./cmd/eidovela-migrate"
Build-Go (Join-Path $AxisRoboHome "LIMENORA\backend\go") $limenoraBin "./cmd/server-gateway"

# Create the example databases (idempotent).
$adapter = Join-Path $PSScriptRoot "..\..\adapters\presentation-client"
$prevInit = $env:FP1_INIT_DB
$env:FP1_INIT_DB = "1"
Push-Location $adapter
try { go run . } finally { Pop-Location; $env:FP1_INIT_DB = $prevInit }

$nomivelaDSN = "postgres://postgres:postgres@localhost:5433/fp1_nomivela?sslmode=disable"
$eidovelaDSN = "postgres://postgres:postgres@localhost:5433/fp1_eidovela?sslmode=disable"
$limenoraDSN = "postgres://postgres:postgres@localhost:5433/fp1_limenora?sslmode=disable"

# NOMIVELA (migrate on boot).
$env:NOMIVELA_DATABASE_URL = $nomivelaDSN
$env:NOMIVELA_HTTP_PORT = "1956"
$env:NOMIVELA_MIGRATE = "true"
$env:NOMIVELA_API_TOKENS = $env:FP1_NOMIVELA_TOKEN
Start-Process -FilePath $nomivelaBin -RedirectStandardOutput "$logDir\nomivela.out.log" -RedirectStandardError "$logDir\nomivela.err.log" -WindowStyle Hidden

# EIDOVELA migrate (explicit migrations dir), then daemon (consumer mode).
$env:EIDOVELA_DATABASE_URL = $eidovelaDSN
& $eidovelaMig -dir (Join-Path $AxisRoboHome "EIDOVELA\backend\migrations")
$env:EIDOVELA_LISTEN_ADDR = "127.0.0.1:1966"
$env:EIDOVELA_ISSUER = $env:FP1_EIDOVELA_ISSUER
$env:EIDOVELA_NOMIVELA_URL = $env:FP1_NOMIVELA_URL
$env:EIDOVELA_NOMIVELA_NAMESPACE = $env:FP1_NAMESPACE
$env:EIDOVELA_NOMIVELA_TOKEN = $env:FP1_NOMIVELA_TOKEN
$env:EIDOVELA_NOMIVELA_CACHE_TTL = "0s"
$env:EIDOVELA_REQUIRE_DPOP = "1"
Start-Process -FilePath $eidovelaBin -RedirectStandardOutput "$logDir\eidovela.out.log" -RedirectStandardError "$logDir\eidovela.err.log" -WindowStyle Hidden

# LIMENORA server-gateway: agent-egress scenario + federated presentation.
$env:DATABASE_URL = $limenoraDSN
$env:GATEWAY_AGENT_EGRESS_REQUIRED = "true"
$env:GATEWAY_EIDOVELA_URL = $env:FP1_EIDOVELA_URL
$env:GATEWAY_EIDOVELA_AUDIENCE = $env:FP1_AUDIENCE
$env:GATEWAY_RESOURCE_PROOF_CARRIAGE = "request_header"
$env:GATEWAY_AGENT_TUNNEL_POLICY = "deny"
Start-Process -FilePath $limenoraBin -RedirectStandardOutput "$logDir\limenora.out.log" -RedirectStandardError "$logDir\limenora.err.log" -WindowStyle Hidden

# Health checks.
$checks = @("$($env:FP1_NOMIVELA_URL)/healthz", "$($env:FP1_EIDOVELA_URL)/healthz", "$($env:FP1_LIMENORA_URL)/healthz")
foreach ($c in $checks) {
  $ready = $false
  for ($i = 0; $i -lt 30 -and -not $ready; $i++) {
    try { Invoke-WebRequest -UseBasicParsing $c | Out-Null; $ready = $true } catch { Start-Sleep -Seconds 1 }
  }
  if (-not $ready) { throw "Service not ready: $c" }
}
Write-Output "FP-1 services ready."
