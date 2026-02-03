# Build ScribeFlow - Chrome Extension Version
# This script builds the Chrome Extension with Side Panel

Write-Host "Building ScribeFlow Chrome Extension..." -ForegroundColor Cyan

# Ensure we're in the correct directory
$projectRoot = $PSScriptRoot
Set-Location $projectRoot

# Step 1: Temporarily swap web folders
Write-Host "Step 1/4: Swapping folders..." -ForegroundColor Yellow
if (Test-Path "web_backup") {
    Remove-Item -Recurse -Force "web_backup"
}
Rename-Item -Path "web" -NewName "web_backup"
Copy-Item -Path "web_extension" -Destination "web" -Recurse

# Step 2: Build the extension (without service worker)
Write-Host "Step 2/4: Building..." -ForegroundColor Yellow
flutter build web --web-renderer html --csp --no-tree-shake-icons --pwa-strategy=none --base-href "./"

# Step 3: Restore original web folder
Write-Host "Step 3/4: Restoring folders..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "web"
Rename-Item -Path "web_backup" -NewName "web"

# Step 4: Copy extension-specific files to build
Write-Host "Step 4/4: Copying extension files..." -ForegroundColor Yellow
Copy-Item -Path "web_extension\background.js" -Destination "build\web\" -Force

Write-Host ""
Write-Host "Extension Build Complete!" -ForegroundColor Green
Write-Host "Output: build/web/" -ForegroundColor Yellow
Write-Host ""
Write-Host "To install in Chrome:" -ForegroundColor Cyan
Write-Host "  1. Open chrome://extensions" -ForegroundColor White
Write-Host "  2. Enable 'Developer mode'" -ForegroundColor White
Write-Host "  3. Click 'Load unpacked'" -ForegroundColor White
Write-Host "  4. Select the 'build/web' folder" -ForegroundColor White
Write-Host "  5. Click the extension icon to open Side Panel" -ForegroundColor White
