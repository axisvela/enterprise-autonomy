param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Validates the structure of runnable demos and the PowerShell syntax of every
# repository script. Intended for CI and pre-commit use; does not require a
# database or product binaries.

$failures = @()
$demoDirs = @("order-fulfillment-local", "procurement-local", "customer-case-local", "recruitment-local", "predictive-maintenance-local", "integration-recovery-local", "simulation-validation-local", "compliance-audit-local", "fleet-mission-local", "process-to-outcome-local", "innovation-sandbox-local", "deployment-local")

foreach ($name in $demoDirs) {
  $dir = Join-Path $Root "examples\$name"
  $required = @("README.md", "operations-guide.md", "local.env.ps1.example", "evidence-schema.md", "run-all.ps1", "verify.ps1", "start-services.ps1")
  foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $dir $f))) { $failures += "$name missing $f" }
  }
}

# PowerShell syntax check across all scripts
$psFiles = Get-ChildItem -Path (Join-Path $Root "scripts"), (Join-Path $Root "examples") -Recurse -Filter *.ps1
foreach ($f in $psFiles) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  foreach ($e in $parseErrors) { $failures += "$($f.Name): $($e.Message)" }
}

if ($failures.Count -eq 0) {
  Write-Host "validate-demos: structure and script syntax OK ($($psFiles.Count) scripts, $($demoDirs.Count) demos)." -ForegroundColor Green
  exit 0
}
$failures | ForEach-Object { Write-Host "validate-demos: $_" -ForegroundColor Red }
Write-Host "validate-demos: $($failures.Count) issue(s) found." -ForegroundColor Red
exit 1
