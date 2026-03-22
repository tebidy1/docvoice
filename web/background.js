// Background Service Worker
chrome.runtime.onInstalled.addListener(() => {
    console.log("ScribeFlow Extension Installed");
    chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
});
