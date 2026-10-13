param()

if (-not $AxisRoboHome -or -not $env:DATABASE_URL) {
  throw "Load local.env.ps1 before running this script."
}

$logDir = Join-Path $PSScriptRoot ".local-logs"
$dataDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $logDir, $dataDir, (Join-Path $PSScriptRoot ".praxovela") | Out-Null

$services = @(
  @{ Name = "limenora"; File = Join-Path $AxisRoboHome "tmp\release\v0.8.0\windows-amd64\limenora-edge.exe"; Args = "--port 1896 --data-dir `"$dataDir\limenora`"" },
  @{ Name = "ontovela"; File = Join-Path $AxisRoboHome "ONTOVELA\backend\ontovela.exe"; Args = "serve --addr :1856" },
  @{ Name = "rheovela"; File = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"; Args = "serve --addr :1876 --db `"$dataDir\rheovela.db`"" },
  @{ Name = "symbivela"; File = Join-Path $AxisRoboHome "SYMBIVELA\backend\symbivela.exe"; Args = "" }
)

foreach ($service in $services) {
  if (-not (Test-Path $service.File)) { throw "Binary not found: $($service.File)" }
  $startArgs = @{ FilePath = $service.File; RedirectStandardOutput = "$logDir\$($service.Name).out.log"; RedirectStandardError = "$logDir\$($service.Name).err.log"; WindowStyle = "Hidden" }
  if ($service.Args) { $startArgs.ArgumentList = $service.Args }
  Start-Process @startArgs
}

$previousAxonPort = $env:AXON_PORT
$env:AXON_PORT = "1866"
$praxovela = Join-Path $AxisRoboHome "PRAXOVELA\packages\axon-core\axond.exe"
if (-not (Test-Path $praxovela)) { throw "Binary not found: $praxovela" }
$previousBoundaries = $env:PRAXOVELA_BOUNDARIES
$env:PRAXOVELA_BOUNDARIES = Join-Path $PSScriptRoot "inference-boundaries.yaml"
Start-Process -FilePath $praxovela -WorkingDirectory (Join-Path $AxisRoboHome "PRAXOVELA") -RedirectStandardOutput "$logDir\praxovela.out.log" -RedirectStandardError "$logDir\praxovela.err.log" -WindowStyle Hidden
$env:PRAXOVELA_BOUNDARIES = $previousBoundaries
$env:AXON_PORT = $previousAxonPort

$moduregisReleaseDir = Join-Path $PSScriptRoot ".moduregis-release"
New-Item -ItemType Directory -Force -Path $moduregisReleaseDir | Out-Null
foreach ($name in @("moduregis-api.exe", "moduregis-migrate.exe")) {
  $target = Join-Path $moduregisReleaseDir $name
  if (-not (Test-Path $target)) {
    $zipName = $name -replace "\.exe$", ""
    $zipName = $zipName -replace "moduregis-api", "moduregis-api_v1.0.1_windows_amd64"
    $zipName = $zipName -replace "moduregis-migrate", "moduregis-migrate_v1.0.1_windows_amd64"
    $zipPath = Join-Path $moduregisReleaseDir "$zipName.zip"
    if (-not (Test-Path $zipPath)) {
      $url = "https://github.com/axisrobo/moduregis-open/releases/download/v1.0.1/$zipName.zip"
      Write-Host "Downloading $url"
      Invoke-WebRequest -UseBasicParsing $url -OutFile $zipPath
    }
    Expand-Archive -Path $zipPath -DestinationPath $moduregisReleaseDir -Force
  }
}
$moduregisMigrationDir = Join-Path $moduregisReleaseDir "migrations"
if ($ModuregisSource) {
  $sourceMigrationDir = Join-Path $ModuregisSource "deploy\postgres\migrations"
  if (Test-Path $sourceMigrationDir) {
    New-Item -ItemType Directory -Force -Path $moduregisMigrationDir | Out-Null
    Get-ChildItem (Join-Path $sourceMigrationDir "*.sql") | Where-Object { $_.Name -notlike "*remove_invocation_grant_token*" } | Copy-Item -Destination $moduregisMigrationDir -Force
  }
}
$previousModuregisDatabaseURL = $env:DATABASE_URL
$previousModuregisEnv = $env:MODUREGIS_ENV
$previousAegivelaMode = $env:AEGIVELA_MODE
$previousModuregisListen = $env:LISTEN_ADDR
$env:DATABASE_URL = $env:MODUREGIS_DATABASE_URL
$env:MODUREGIS_ENV = "development"
$env:AEGIVELA_MODE = "stub"
$env:LISTEN_ADDR = $ModuregisListenAddr
$moduregisMigrate = Join-Path $moduregisReleaseDir "moduregis-migrate.exe"
if (Test-Path $moduregisMigrate -PathType Leaf) {
  Push-Location $moduregisReleaseDir
  & $moduregisMigrate -migration-dir ".\migrations"
  Pop-Location
}
$moduregisApi = Join-Path $moduregisReleaseDir "moduregis-api.exe"
$moduregisCmd = "/c set DATABASE_URL=$env:MODUREGIS_DATABASE_URL&& set MODUREGIS_ENV=development&& set AEGIVELA_MODE=stub&& set LISTEN_ADDR=$ModuregisListenAddr&& $moduregisApi"
Start-Process -FilePath "cmd.exe" -ArgumentList $moduregisCmd -WorkingDirectory $moduregisReleaseDir -RedirectStandardOutput "$logDir\moduregis.out.log" -RedirectStandardError "$logDir\moduregis.err.log" -WindowStyle Hidden
$env:DATABASE_URL = $previousModuregisDatabaseURL
$env:MODUREGIS_ENV = $previousModuregisEnv
$env:AEGIVELA_MODE = $previousAegivelaMode
$env:LISTEN_ADDR = $previousModuregisListen

$adapterDir = Join-Path $PSScriptRoot "..\..\adapters\inference-domain"
$adapterBinary = Join-Path $adapterDir "inference-domain-adapter.exe"
if (-not (Test-Path $adapterBinary)) {
  $previousGoWork = $env:GOWORK
  $env:GOWORK = "off"
  Push-Location $adapterDir
  go build -o $adapterBinary .
  Pop-Location
  $env:GOWORK = $previousGoWork
}
Start-Process -FilePath $adapterBinary -ArgumentList "--addr :8103 --data-file `"$dataDir\inference-domain-data.json`"" -RedirectStandardOutput "$logDir\inference-domain.out.log" -RedirectStandardError "$logDir\inference-domain.err.log" -WindowStyle Hidden

$checks = @("http://localhost:1896/healthz", "http://localhost:1856/healthz", "http://localhost:1876/api/v1/health", "http://localhost:1926/ready", "http://127.0.0.1:1866/health", "http://localhost:8103/healthz")
foreach ($check in $checks) {
  $ready = $false
  for ($attempt = 0; $attempt -lt 20 -and -not $ready; $attempt++) {
    try {
      $params = @{ Uri = $check; UseBasicParsing = $true }
      if ($check -like "http://localhost:1856*") { $params.Headers = @{ "X-Tenant-ID" = $TenantId } }
      Invoke-WebRequest @params | Out-Null
      $ready = $true
    } catch { Start-Sleep -Seconds 1 }
  }
  if (-not $ready) { throw "Service did not become ready: $check" }
}
Write-Host "All local services are ready."
