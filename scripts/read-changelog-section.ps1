param(
  [Parameter(Mandatory = $true)]
  [string]$Ver,
  [string]$Changelog = ""
)

if (-not $Changelog) { $Changelog = Join-Path $PSScriptRoot "..\CHANGELOG.md" }

if (-not (Test-Path $Changelog)) { Write-Error "Changelog not found: $Changelog"; exit 1 }
$content = Get-Content -Raw $Changelog
$escaped = [regex]::Escape($Ver)
$pattern = "##\s+$escaped\s*\([^)]*\)(?<body>.*?)(?=\r?\n##\s|\Z)"
$m = [regex]::Match($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $m.Success) {
  Write-Error "No changelog section found for version $Ver"
  exit 1
}
$body = $m.Groups["body"].Value.Trim()
if (-not $body) { Write-Error "Changelog section for $Version is empty"; exit 1 }
Write-Output $body
exit 0
