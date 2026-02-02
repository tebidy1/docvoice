// Background Service Worker for Side Panel
// This script opens the side panel when the extension icon is clicked

chrome.action.onClicked.addListener((tab) => {
  // Open the side panel for the current tab
  chrome.sidePanel.open({ tabId: tab.id });
});
