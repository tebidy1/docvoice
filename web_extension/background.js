// Background service worker for Side Panel toggle behavior mechanism
// This is required for the side panel permission usage in some contexts
// Even if empty, it's good practice to have it.

chrome.sidePanel
    .setPanelBehavior({ openPanelOnActionClick: true })
    .catch((error) => console.error(error));

chrome.runtime.onInstalled.addListener(() => {
    console.log("ScribeFlow Side Panel Extension Installed/Updated");
});
