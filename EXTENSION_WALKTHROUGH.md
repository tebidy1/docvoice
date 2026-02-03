# Flutter Extension Build Walkthrough

## Summary
We have successfully transitioned the project to a **dedicated Extension Build Architecture**. This resolves the "white screen" and "path resolution" issues by separating the Extension logic from the standard Web/PWA logic.

## Changes Implemented

### 1. Dedicated Entry Point (`lib/main_extension.dart`)
- Created a simplified Flutter entry point.
- Removed PWA-specific code (Service Workers, complex routing).
- Removed Desktop-specific dependencies (WindowManager) that caused crashes in the Extension environment.
- Added localized `.env` loading for the extension.

### 2. Custom Extension Loader (`web_extension/index.html`)
- Created a custom HTML loader that uses `flutter.js` directly.
- **Bypasses** the standard `flutter_bootstrap.js` which was causing path issues.
- **Disables** Service Worker registration explicitly to prevent Side Panel conflicts.
- forces `renderer: 'html'` (or 'canvaskit' if needed) with `assetBase: './'` to ensure all assets load relative to the extension root.

### 3. Extension Manifest V3 (`web_extension/manifest.json`)
- Defined a proper Chrome Extension Manifest V3.
- Permissions: `sidePanel`, `storage`, `activeTab`.
- CSP Policy: configured to allow Flutter Web execution (`wasm-unsafe-eval`).

### 4. Build Script (`build_extension_clean.ps1`)
- Created a PowerShell script to automate the build:
    1. Cleans `build/web`.
    2. Builds Flutter using `main_extension.dart`.
    3. Overwrites standard web files with `web_extension` files.
    4. Cleans up PWA artifacts.

## How to Test

1. **Go to Chrome Extensions Page**:
   - Open `chrome://extensions` in your browser.
   - Enable **Developer mode** (top right).

2. **Load Unpacked**:
   - Click **Load unpacked**.
   - Select the `build/web` folder in your project directory:
     `E:\d\DOCVOICE-ORG\docvoice\build\web`

3. **Open Side Panel**:
   - Click the Extension icon in the toolbar.
   - The Side Panel should open and load the application successfully.

## Troubleshooting
- If you see a **White Screen**: Check the Console (Right-click inside Side Panel -> Inspect).
- If you see `net::ERR_FILE_NOT_FOUND`: Ensure `assetBase: './'` is preserved in `index.html`.
