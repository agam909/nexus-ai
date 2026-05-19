# One-shot backend bootstrap. Run from project root.
$ErrorActionPreference = "Stop"

Push-Location backend
try {
    if (-not (Test-Path .venv)) {
        Write-Host "Creating Python venv..." -ForegroundColor Cyan
        python -m venv .venv
    }

    & .\.venv\Scripts\Activate.ps1

    Write-Host "Installing dependencies (this can take a few minutes)..." -ForegroundColor Cyan
    python -m pip install --upgrade pip
    pip install -r requirements.txt

    if (-not (Test-Path .env)) {
        Write-Host "Creating .env from template - edit it and add your GROQ_API_KEY." -ForegroundColor Yellow
        Copy-Item .env.example .env
    }

    Write-Host "`nSetup complete. Start the server with:" -ForegroundColor Green
    Write-Host "  cd backend; .\.venv\Scripts\Activate.ps1; .\run.ps1" -ForegroundColor Green
}
finally {
    Pop-Location
}
