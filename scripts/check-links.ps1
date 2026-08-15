param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

$files = Get-ChildItem -Path $Root -Recurse -Filter *.md
$broken = @()
foreach ($f in $files) {
  $content = Get-Content $f.FullName -Raw
  $matches = [regex]::Matches($content, '\[[^\]]*\]\(([^)]+)\)')
  foreach ($m in $matches) {
    $target = $m.Groups[1].Value
    if ($target -match '^(http|https|#)') { continue }
    if ($target -match '^mailto:') { continue }
    $path = $target.Split('#')[0]
    if ($path -eq '') { continue }
    $resolved = Join-Path (Split-Path $f.FullName) $path
    if (-not (Test-Path $resolved)) { $broken += "$($f.FullName) -> $target" }
  }
}

if ($broken.Count -eq 0) {
  Write-Host "check-links: OK - no broken internal links." -ForegroundColor Green
  exit 0
}
Write-Host "check-links: $($broken.Count) broken internal link(s)." -ForegroundColor Red
$broken | ForEach-Object { Write-Host $_ }
exit 1
