param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Kills any reference-adapter process built from this repository. Used for CI
# hygiene and after interrupted demo runs.

$adapterDir = Join-Path $RepoRoot "adapters\"
$procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($adapterDir, [System.StringComparison]::OrdinalIgnoreCase) }

$ids = @($procs | Select-Object -ExpandProperty ProcessId -Unique)
if ($ids.Count -eq 0) {
  Write-Host "kill-adapters: no adapter processes found." -ForegroundColor Yellow
  exit 0
}
foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 300
Write-Host "kill-adapters: killed $($ids.Count) adapter process(es)." -ForegroundColor Green
