param(
  [Parameter(Position = 0)]
  [ValidateSet("get", "set", "bump")]
  [string]$Command = "get",
  [Parameter(Position = 1)]
  [string]$Value = "",
  [string]$VersionFile = ""
)

if (-not $VersionFile) { $VersionFile = Join-Path $PSScriptRoot "..\VERSION" }

function Read-Version {
  if (-not (Test-Path $VersionFile)) { throw "Version file not found: $VersionFile" }
  return (Get-Content $VersionFile -Raw).Trim()
}

function Write-Version($version) {
  if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw "Version must be major.minor.patch, got '$version'" }
  Set-Content -Path $VersionFile -Value $version -NoNewline
  return $version
}

function Bump-Version($part, $current) {
  $parts = $current -split '\.'
  $maj = [int]$parts[0]; $min = [int]$parts[1]; $pat = [int]$parts[2]
  switch ($part) {
    "major" { $maj++; $min = 0; $pat = 0 }
    "minor" { $min++; $pat = 0 }
    "patch" { $pat++ }
    default { throw "Bump part must be major, minor, or patch, got '$part'" }
  }
  return "$maj.$min.$pat"
}

$current = Read-Version
switch ($Command) {
  "get"  { Write-Output $current }
  "set"  { Write-Output (Write-Version $Value) }
  "bump" { Write-Output (Write-Version (Bump-Version $Value $current)) }
}
