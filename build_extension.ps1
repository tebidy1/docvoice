# Build ScribeFlow - Chrome Extension Version
# This script builds the Chrome Extension with Side Panel

Write-Host "Building ScribeFlow Chrome Extension..." -ForegroundColor Cyan

# Ensure we're in the correct directory
$projectRoot = $PSScriptRoot
Set-Location $projectRoot

# Step 1: Temporarily swap web folders
Write-Host "Step 1/6: Swapping folders..." -ForegroundColor Yellow
if (Test-Path "web_backup") {
    Remove-Item -Recurse -Force "web_backup"
}
Rename-Item -Path "web" -NewName "web_backup"
Copy-Item -Path "web_extension" -Destination "web" -Recurse

# Step 2: Build the extension (without service worker)
flutter build web --csp --no-tree-shake-icons --pwa-strategy=none

# Step 3: Restore original web folder (patch BEFORE restoring)
Write-Host "Step 3/5: Patching flutter_bootstrap.js for Chrome Extension..." -ForegroundColor Yellow
$bootstrapPath = "build\web\flutter_bootstrap.js"
if (Test-Path $bootstrapPath) {
    $js = Get-Content $bootstrapPath -Raw -Encoding UTF8
    # Remove serviceWorkerSettings and set canvasKitBaseUrl to local folder
    # Chrome Extensions cannot register Service Workers from extension pages,
    # and cannot load CanvasKit from gstatic.com CDN due to CSP restrictions.
    $js = $js -replace '_flutter\.loader\.load\(\{[\s\S]*?\}\);', "_flutter.loader.load({`n  config: {`n    canvasKitBaseUrl: `"canvaskit/`"`n  }`n});"
    Set-Content $bootstrapPath $js -NoNewline -Encoding UTF8
    Write-Host "  - Removed service worker registration" -ForegroundColor Gray
    Write-Host "  - Set CanvasKit to local 'canvaskit/' folder" -ForegroundColor Gray
}
else {
    Write-Warning "flutter_bootstrap.js not found - patch skipped"
}

# Empty flutter_service_worker.js to prevent errors
$swPath = "build\web\flutter_service_worker.js"
if (Test-Path $swPath) {
    "// Disabled for Chrome Extension" | Set-Content $swPath -Encoding UTF8
    Write-Host "  - flutter_service_worker.js cleared" -ForegroundColor Gray
}

# Step 4: Restore original web folder
Write-Host "Step 4/5: Restoring folders..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "web"
Rename-Item -Path "web_backup" -NewName "web"


# Step 5: Copy extension-specific files to build
Write-Host "Step 5/5: Copying extension files..." -ForegroundColor Yellow
Copy-Item -Path "web_extension\background.js" -Destination "build\web\" -Force
# IMPORTANT: copy the extension manifest explicitly so CSP / permissions are correct
Copy-Item -Path "web_extension\manifest.json" -Destination "build\web\" -Force
Copy-Item -Path "web_extension\content_script.js" -Destination "build\web\" -Force
Write-Host "  - Copied web_extension/manifest.json (with correct CSP) and content_script.js" -ForegroundColor Gray

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
