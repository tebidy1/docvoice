# Build Scribe Flow - PWA Version
# This script builds the Progressive Web App version

Write-Host "Building ScribeFlow PWA..." -ForegroundColor Cyan

# Ensure we're in the correct directory
$projectRoot = $PSScriptRoot
Set-Location $projectRoot

# Build the PWA
flutter build web --release

Write-Host ""
Write-Host "PWA Build Complete!" -ForegroundColor Green
Write-Host "Output: build/web/" -ForegroundColor Yellow
Write-Host ""
Write-Host "To test locally:" -ForegroundColor Cyan
Write-Host "  cd build/web" -ForegroundColor White
Write-Host "  python -m http.server 8000" -ForegroundColor White
Write-Host "  Then open: http://localhost:8000" -ForegroundColor White
