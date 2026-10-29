param(
  [string]$Psql = "psql",
  [Parameter(Mandatory = $true)][string]$AdminDSN,
  [string]$Prefix = "iro_"
)

$ErrorActionPreference = "Stop"

if ($Prefix -notmatch '^[a-z0-9_]+$') { throw "Prefix must contain only lowercase letters, digits, and underscores" }

$databases = @(
  @{ Name = "${Prefix}symbivela"; Owner = "symbivela" },
  @{ Name = "${Prefix}orchadyn"; Owner = "orchadyn" },
  @{ Name = "${Prefix}moduregis"; Owner = "moduregis" }
)

$psqlCommand = Get-Command $Psql -ErrorAction SilentlyContinue
if (-not $psqlCommand) { throw "psql not found: $Psql" }

foreach ($database in $databases) {
  if ($database.Name -notmatch '^[a-z0-9_]+$' -or $database.Owner -notmatch '^[a-z0-9_]+$') {
    throw "Invalid database or owner name"
  }
  & $psqlCommand.Source $AdminDSN -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS `"$($database.Name)`" WITH (FORCE)"
  if ($LASTEXITCODE -ne 0) { throw "Failed to drop $($database.Name)" }
  & $psqlCommand.Source $AdminDSN -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$($database.Name)`" OWNER `"$($database.Owner)`""
  if ($LASTEXITCODE -ne 0) { throw "Failed to create $($database.Name)" }
  Write-Host "reset database $($database.Name) (owner $($database.Owner))"
}
