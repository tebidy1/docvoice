# ScribeFlow Professional Extension Build Script
# usage: .\build_extension_clean.ps1

Write-Host "Starting Professional Extension Build..." -ForegroundColor Cyan

# 1. Clean previous build
if (Test-Path "build/web") {
    Remove-Item -Recurse -Force "build/web"
}

# 2. Build Flutter Web using Dedicated Entry Point
# We use --pwa-strategy=none to avoid generating service worker related code
# We use --web-renderer html for max compatibility
# We use --csp because extensions require Content Security Policy compliance
Write-Host "Compiling Flutter (Target: main_extension.dart)..." -ForegroundColor Yellow
flutter build web -t lib/main_extension.dart --web-renderer html --csp --no-tree-shake-icons --pwa-strategy=none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build Failed!" -ForegroundColor Red
    exit 1
}

# 3. Post-Build: Overwrite with Extension-Specific Files
Write-Host "Applying Extension Configuration..." -ForegroundColor Yellow

$buildDir = "build/web"
$extDir = "web_extension"

# Replace index.html (Our custom loader)
Copy-Item "$extDir/index.html" "$buildDir/index.html" -Force

# Replace manifest.json (Extension manifest)
Copy-Item "$extDir/manifest.json" "$buildDir/manifest.json" -Force

# Add background.js (Service Worker)
Copy-Item "$extDir/background.js" "$buildDir/background.js" -Force

# Add extension_loader_v2.js
Copy-Item "$extDir/extension_loader_v2.js" "$buildDir/extension_loader_v2.js" -Force

# Add icons if missing (Flutter usually copies what's in web/icons, but extension might need generic ones)
if (Test-Path "$extDir/icons") {
    Copy-Item "$extDir/icons" "$buildDir" -Recurse -Force
}

# 4. Clean up PWA artifacts that might confuse Chrome
if (Test-Path "$buildDir/flutter_service_worker.js") {
    Remove-Item "$buildDir/flutter_service_worker.js" -Force
}
if (Test-Path "$buildDir/version.json") {
    Remove-Item "$buildDir/version.json" -Force
}

Write-Host ""
Write-Host "✅ Extension Build Complete Successfully!" -ForegroundColor Green
Write-Host "Load directory: build/web" -ForegroundColor White
Write-Host "Don't forget to click 'Refresh' in chrome://extensions" -ForegroundColor White
