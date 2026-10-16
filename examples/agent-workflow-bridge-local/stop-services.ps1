# Stops the processes this example started (by pid files in .local-data).
$dataDir = Join-Path $PSScriptRoot ".local-data"
$names = @('axond', 'rheo-windows-amd64', 'rheo', 'aegivela-api')
foreach ($f in Get-ChildItem $dataDir -Filter *.pid -ErrorAction SilentlyContinue) {
  $pidValue = Get-Content $f.FullName -ErrorAction SilentlyContinue
  if (-not $pidValue) { continue }
  $proc = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
  if ($proc) {
    Write-Output ("[stop-services] stopping {0} pid {1}" -f $proc.ProcessName, $proc.Id)
    Stop-Process -Id $proc.Id -Force
  }
  Remove-Item $f.FullName -ErrorAction SilentlyContinue
}

# Fall back to name matching in case a pid file was lost.
foreach ($n in $names) {
  Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output ("[stop-services] stopping stray {0} pid {1}" -f $_.ProcessName, $_.Id)
    Stop-Process -Id $_.Id -Force
  }
}
Write-Output "[stop-services] done (dev keys/DB stay in .local-data; delete them by hand to reset)"
