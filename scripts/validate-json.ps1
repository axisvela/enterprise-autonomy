param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Validates that every JSON file under examples/ and adapters/ parses.
# This catches malformed plan and workflow definitions early.

$failures = @()
$count = 0
$jsonFiles = Get-ChildItem -Path (Join-Path $Root "examples"), (Join-Path $Root "adapters") -Recurse -Filter *.json -ErrorAction SilentlyContinue
foreach ($f in $jsonFiles) {
  $count++
  try {
    Get-Content -Raw $f.FullName | ConvertFrom-Json | Out-Null
  } catch {
    $failures += "$($f.FullName): $($_.Exception.Message)"
  }
}

if ($failures.Count -eq 0) {
  Write-Host "validate-json: $count JSON file(s) parse OK." -ForegroundColor Green
  exit 0
}
$failures | ForEach-Object { Write-Host "validate-json: $_" -ForegroundColor Red }
Write-Host "validate-json: $($failures.Count) invalid JSON file(s)." -ForegroundColor Red
exit 1
