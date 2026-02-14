// Background Service Worker
chrome.runtime.onInstalled.addListener(() => {
    console.log("ScribeFlow Extension Installed");
});

// Optional: specific side panel open logic if needed
// chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
