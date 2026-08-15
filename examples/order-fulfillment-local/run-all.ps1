param()

. .\local.env.ps1
.\start-services.ps1
.\run-order-exception.ps1
.\verify.ps1
Write-Host ""
Write-Host "run-all completed: services started, scenario executed, outcome verified." -ForegroundColor Green
