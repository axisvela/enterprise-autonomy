param()

if (-not $AxisRoboHome -or -not $env:DATABASE_URL) {
  throw "Load local.env.ps1 before running this script."
}

$logDir = Join-Path $PSScriptRoot ".local-logs"
$dataDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $logDir, $dataDir, (Join-Path $PSScriptRoot ".praxovela") | Out-Null

$services = @(
  @{ Name = "limenora"; File = Join-Path $AxisRoboHome "tmp\release\v0.8.0\windows-amd64\limenora-edge.exe"; Args = "--port 10255 --data-dir `"$dataDir\limenora`"" },
  @{ Name = "ontovela"; File = Join-Path $AxisRoboHome "ONTOVELA\backend\ontovela.exe"; Args = "serve --addr :8082" },
  @{ Name = "rheovela"; File = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"; Args = "serve --addr :8083 --db `"$dataDir\rheovela.db`"" },
  @{ Name = "symbivela"; File = Join-Path $AxisRoboHome "SYMBIVELA\backend\symbivela.exe"; Args = "" }
)

foreach ($service in $services) {
  if (-not (Test-Path $service.File)) { throw "Binary not found: $($service.File)" }
  Start-Process -FilePath $service.File -ArgumentList $service.Args -RedirectStandardOutput "$logDir\$($service.Name).out.log" -RedirectStandardError "$logDir\$($service.Name).err.log" -WindowStyle Hidden
}

$praxovela = Join-Path $AxisRoboHome "PRAXOVELA\packages\axon-core\axond.exe"
if (-not (Test-Path $praxovela)) { throw "Binary not found: $praxovela" }
$previousBoundaries = $env:PRAXOVELA_BOUNDARIES
$env:PRAXOVELA_BOUNDARIES = Join-Path $PSScriptRoot "praxovela-boundaries.yaml"
Start-Process -FilePath $praxovela -WorkingDirectory (Join-Path $AxisRoboHome "PRAXOVELA") -RedirectStandardOutput "$logDir\praxovela.out.log" -RedirectStandardError "$logDir\praxovela.err.log" -WindowStyle Hidden
$env:PRAXOVELA_BOUNDARIES = $previousBoundaries

$checks = @("http://localhost:10255/healthz", "http://localhost:8082/healthz", "http://localhost:8083/api/v1/health", "http://localhost:8080/ready", "http://127.0.0.1:8420/health")
foreach ($check in $checks) {
  $ready = $false
  for ($attempt = 0; $attempt -lt 20 -and -not $ready; $attempt++) {
    try { Invoke-WebRequest -UseBasicParsing $check | Out-Null; $ready = $true } catch { Start-Sleep -Seconds 1 }
  }
  if (-not $ready) { throw "Service did not become ready: $check" }
}
Write-Host "All local services are ready."
