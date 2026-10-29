param(
  [string]$Psql = "psql",
  [Parameter(Mandatory = $true)][string]$AdminDSN
)

$ErrorActionPreference = "Stop"
. .\local.env.ps1

$axisVelaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $ModuregisSource -or -not (Test-Path (Join-Path $ModuregisSource 'deploy\postgres\migrations'))) {
  $ModuregisSource = Join-Path $axisVelaRoot 'MODUREGIS'
}
if (-not $OrchadynSource -or -not (Test-Path (Join-Path $OrchadynSource 'backend\migrations'))) {
  $OrchadynSource = Join-Path $axisVelaRoot 'ORCHADYN'
}

function Replace-Database([string]$url, [string]$database) {
  $builder = [System.UriBuilder]::new($url)
  $builder.Path = "/$database"
  return $builder.Uri.AbsoluteUri
}

& (Join-Path $PSScriptRoot 'reset-databases.ps1') -Psql $Psql -AdminDSN $AdminDSN -Prefix 'iro_'
if ($LASTEXITCODE -ne 0) { throw 'database reset failed' }

$env:DATABASE_URL = Replace-Database $env:DATABASE_URL 'iro_symbivela'
$env:ORCHADYN_DATABASE_URL = Replace-Database $env:ORCHADYN_DATABASE_URL 'iro_orchadyn'
$env:MODUREGIS_DATABASE_URL = Replace-Database $env:MODUREGIS_DATABASE_URL 'iro_moduregis'

$symbivelaBackend = Join-Path $axisVelaRoot 'SYMBIVELA\backend'
if (-not (Test-Path $symbivelaBackend)) { $symbivelaBackend = Join-Path $AxisVelaHome 'SYMBIVELA\backend' }
$symbivelaMigrate = Join-Path $symbivelaBackend 'symbivela-migrate.exe'
if (-not (Test-Path $symbivelaMigrate)) {
  $previousGoWork = $env:GOWORK
  $env:GOWORK = 'off'
  Push-Location $symbivelaBackend
  go build -o $symbivelaMigrate ./cmd/symbivela-migrate
  $buildExit = $LASTEXITCODE
  Pop-Location
  $env:GOWORK = $previousGoWork
  if ($buildExit -ne 0) { throw 'symbivela-migrate build failed' }
}
Push-Location $symbivelaBackend
$env:SYMBIVELA_MIGRATIONS_DIR = Join-Path $symbivelaBackend 'deploy\postgres\migrations'
& $symbivelaMigrate
$migrateExit = $LASTEXITCODE
Pop-Location
if ($migrateExit -ne 0) { throw 'symbivela migration failed' }

$dataDir = Join-Path $PSScriptRoot '.local-data'
foreach ($name in @('rheovela.db', 'integration-domain-data.json', 'integration-outcome.json', 'integration-value-report.json')) {
  Remove-Item -LiteralPath (Join-Path $dataDir $name) -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath (Join-Path $dataDir 'limenora') -Recurse -Force -ErrorAction SilentlyContinue

$result = 0
try {
  & (Join-Path $PSScriptRoot 'start-services.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'start-services failed' }
  & (Join-Path $PSScriptRoot 'run-integration-recovery.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'scenario failed' }
  & (Join-Path $PSScriptRoot 'verify.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'verify failed' }
} catch {
  Write-Host ("clean E2E failed: " + $_.Exception.Message)
  $result = 1
} finally {
  & (Join-Path $PSScriptRoot '..\stop-demo.ps1')
}
exit $result
