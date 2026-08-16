param(
  [string]$Ver = ""
)

# Prints the release body (CHANGELOG section) that would be used for v<Ver>,
# without creating anything. Useful for previewing release notes before a
# release, e.g. when bumping VERSION ahead of time.

$body = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "read-changelog-section.ps1") $Ver
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host "release-body-preview: notes for v$Ver" -ForegroundColor Cyan
Write-Host "---"
Write-Output $body
Write-Host "---"
Write-Host "release-body-preview: preview complete." -ForegroundColor Green
exit 0
