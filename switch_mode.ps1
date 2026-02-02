param (
    [string]$mode
)

if ($mode -ne "pwa" -and $mode -ne "extension") {
    Write-Host "Usage: .\switch_mode.ps1 [pwa|extension]" -ForegroundColor Red
    exit 1
}

# Check if we are currently in Extension mode (web_pwa folder exists) or PWA mode (web_extension folder exists)
$hasWebPwa = Test-Path "web_pwa"
$hasWebExt = Test-Path "web_extension"

if ($mode -eq "pwa") {
    if ($hasWebExt) {
        Write-Host "Already in PWA Mode." -ForegroundColor Yellow
        exit 0
    }
    if (-not $hasWebPwa) {
         # Assuming current 'web' is Extension, and we lack a backup. 
         # This shouldn't happen if followed correctly, but let's assume we want to swap current 'web' to 'web_extension' and 'web_pwa' to 'web'
         Write-Host "Error: Could not find web_pwa folder to restore." -ForegroundColor Red
         exit 1
    }

    Write-Host "Switching to PWA Mode..." -ForegroundColor Cyan
    # 1. Rename current 'web' (Extension) to 'web_extension'
    Rename-Item -Path "web" -NewName "web_extension"
    # 2. Rename 'web_pwa' to 'web'
    Rename-Item -Path "web_pwa" -NewName "web"
    Write-Host "Done! You can now build for PWA." -ForegroundColor Green
}

if ($mode -eq "extension") {
    if ($hasWebPwa) {
        Write-Host "Already in Extension Mode." -ForegroundColor Yellow
        exit 0
    }
    if (-not $hasWebExt) {
         Write-Host "Error: Could not find web_extension folder to restore." -ForegroundColor Red
         exit 1
    }

    Write-Host "Switching to Extension Mode..." -ForegroundColor Cyan
    # 1. Rename current 'web' (PWA) to 'web_pwa'
    Rename-Item -Path "web" -NewName "web_pwa"
    # 2. Rename 'web_extension' to 'web'
    Rename-Item -Path "web_extension" -NewName "web"
    Write-Host "Done! You can now build for Chrome Extension." -ForegroundColor Green
}
