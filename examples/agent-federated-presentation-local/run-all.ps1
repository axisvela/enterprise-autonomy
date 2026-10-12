param([switch]$CheckOnly)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\local.env.ps1"

if ($CheckOnly) { Write-Host "structure OK"; exit 0 }

& "$PSScriptRoot\start-services.ps1"
try {
  $adapter = Join-Path $PSScriptRoot "..\..\adapters\presentation-client"
  $env:FP1_REPORT = Join-Path $PSScriptRoot ".local-data\fp1-value-report.json"
  Push-Location $adapter
  try { go run . } finally { Pop-Location }
  & "$PSScriptRoot\verify.ps1"
} finally {
  Get-Process nomivela, eidovelad, limenora-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
