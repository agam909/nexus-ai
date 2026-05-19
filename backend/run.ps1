# Run from backend/ folder. First time:
#   1. python -m venv .venv
#   2. .\.venv\Scripts\Activate.ps1
#   3. pip install -r requirements.txt
#   4. Copy-Item .env.example .env  ; then edit .env with your GROQ_API_KEY
# Then run:  .\run.ps1

if (-not (Test-Path .env)) {
    Write-Host "No .env found - copying from .env.example. Edit it with your GROQ_API_KEY." -ForegroundColor Yellow
    Copy-Item .env.example .env
}

$env:PYTHONUNBUFFERED = "1"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
