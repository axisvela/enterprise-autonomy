param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Stops every process launched by a local demo. It identifies processes by
# executable path, so it never touches unrelated processes:
#   - reference adapters under <repo>/adapters/
#   - product binaries under the demo stack ($AxisRoboHome + demo release dirs)

$AxisRoboHome = $env:AxisRoboHome
if (-not $AxisRoboHome) { $AxisRoboHome = "D:\profile\paper-code" }

$patterns = @(
  (Join-Path $RepoRoot "adapters\"),
  (Join-Path $AxisRoboHome "PRAXOVELA\packages\axon-core\"),
  (Join-Path $AxisRoboHome "tmp\release\"),
  (Join-Path $AxisRoboHome "ONTOVELA\"),
  (Join-Path $AxisRoboHome "RHEOVELA\"),
  (Join-Path $AxisRoboHome "SYMBIVELA\"),
  (Join-Path $RepoRoot "examples\order-fulfillment-local\.orchadyn-release\"),
  (Join-Path $RepoRoot "examples\order-fulfillment-local\.moduregis-release\"),
  (Join-Path $RepoRoot "examples\procurement-local\.orchadyn-release\"),
  (Join-Path $RepoRoot "examples\procurement-local\.moduregis-release\"),
  (Join-Path $RepoRoot "examples\customer-case-local\.orchadyn-release\"),
  (Join-Path $RepoRoot "examples\customer-case-local\.moduregis-release\"),
  (Join-Path $RepoRoot "examples\recruitment-local\.orchadyn-release\"),
  (Join-Path $RepoRoot "examples\recruitment-local\.moduregis-release\")
)

$targets = @()
foreach ($pattern in $patterns) {
  $norm = $pattern.Replace('/', '\')
  $targets += Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($norm, [System.StringComparison]::OrdinalIgnoreCase) }
}

$ids = @($targets | Select-Object -ExpandProperty ProcessId -Unique)
if ($ids.Count -eq 0) {
  Write-Host "stop-demo: no demo processes found." -ForegroundColor Yellow
  exit 0
}
foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500
Write-Host "stop-demo: stopped $($ids.Count) demo process(es)." -ForegroundColor Green
