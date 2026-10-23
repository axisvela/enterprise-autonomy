param(
  [int]$Port = 8091,
  [string]$Token = "local-demo-token"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$tmp = Join-Path $env:TEMP ("praxo-a2a-adk-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmp | Out-Null
$serverExe = Join-Path $tmp "praxo-server.exe"
$clientExe = Join-Path $tmp "adk-client.exe"
$previousGoWork = $env:GOWORK
$previousToken = $env:PRAXO_A2A_TOKEN
$server = $null
$failures = @()

function Assert-True($condition, $message) {
  if ($condition) {
    Write-Host "PASS: $message" -ForegroundColor Green
  } else {
    Write-Host "FAIL: $message" -ForegroundColor Red
    $script:failures += $message
  }
}

function Invoke-Client($exe, $cardURL, $token, $prompt) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = (& $exe -card $cardURL -token $token -prompt $prompt 2>&1 | Out-String)
    return [pscustomobject]@{ Output = $output; ExitCode = $LASTEXITCODE }
  } finally {
    $ErrorActionPreference = $previous
  }
}

try {
  $env:GOWORK = "off"
  Push-Location $root
  go build -o $serverExe ./cmd/praxo-server
  if ($LASTEXITCODE -ne 0) { throw "failed to build praxo-server" }
  go build -o $clientExe ./cmd/adk-client
  if ($LASTEXITCODE -ne 0) { throw "failed to build adk-client" }
  Pop-Location

  $env:PRAXO_A2A_TOKEN = $Token
  $server = Start-Process -FilePath $serverExe -ArgumentList @("-addr", "127.0.0.1:$Port") -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $tmp "server.out.log") -RedirectStandardError (Join-Path $tmp "server.err.log")

  $cardURL = "http://127.0.0.1:$Port"
  $ready = $false
  $deadline = (Get-Date).AddSeconds(10)
  while ((Get-Date) -lt $deadline) {
    try {
      Invoke-RestMethod -Uri "$cardURL/.well-known/agent-card.json" -TimeoutSec 1 | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 200
    }
  }
  if (-not $ready) {
    throw "PRAXO A2A server did not become ready; see $tmp"
  }

  $approved = Invoke-Client $clientExe $cardURL $Token "Cancel order-1001"
  Assert-True ($approved.ExitCode -eq 0 -and $approved.Output.Contains("approved: order-1001")) "authorized ADK consumer receives approval"

  $denied = Invoke-Client $clientExe $cardURL $Token "Cancel order-1002"
  Assert-True ($denied.ExitCode -eq 0 -and $denied.Output.Contains("denied: order-1002 has shipped")) "authorized ADK consumer receives business denial"

  $unauthorized = Invoke-Client $clientExe $cardURL "wrong-token" "Cancel order-1001"
  Assert-True ($unauthorized.ExitCode -ne 0 -and ($unauthorized.Output -match "401|unauthorized")) "wrong token is rejected"
} finally {
  if ($server -and -not $server.HasExited) {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
  }
  $env:GOWORK = $previousGoWork
  $env:PRAXO_A2A_TOKEN = $previousToken
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
  Write-Host "RUN FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
Write-Host "RUN OK: two-process Google ADK to PRAXO-CORE A2A scenario completed." -ForegroundColor Green
