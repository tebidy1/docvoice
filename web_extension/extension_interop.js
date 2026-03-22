// ScribeFlow Extension Interop
// Handles communication between Flutter (Dart) and Chrome Extensions API

// Define a namespace to avoid collisions
window.scribeflow = {
    // Inject text into the active tab's focused element using Content Script
    injectTextToActiveTab: async function (text) {
        console.log("ScribeFlow: Attempting to inject text via Message Passing...");

        async function sendMessageToTab(tabId, message) {
            return new Promise((resolve, reject) => {
                chrome.tabs.sendMessage(tabId, message, (response) => {
                    if (chrome.runtime.lastError) {
                        reject(chrome.runtime.lastError);
                    } else {
                        resolve(response);
                    }
                });
            });
        }

        try {
            // Find the active tab first
            // We use lastFocusedWindow to get the main browser window when side panel is open
            const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
            if (!tab) {
                console.error("ScribeFlow: No active tab found.");
                return false;
            }

            // Send Message to Content Script
            // The content script tracks the last focused element and will handle insertion.
            try {
                const response = await sendMessageToTab(tab.id, {
                    action: "SCRIBEFLOW_INJECT",
                    text: text
                });

                if (response && response.status === true) {
                    console.log("ScribeFlow: Text injected successfully via content script.");
                    return true;
                }

                console.warn("ScribeFlow: Content script failed to inject (Response: " + JSON.stringify(response) + ")");
                return false;

            } catch (err) {
                console.warn("ScribeFlow: Content script not found or error occurred (" + err.message + "). Attempting to dynamically inject content script...");

                // Fallback: Dynamically inject the content script if it's missing (e.g. after extension reload)
                try {
                    await chrome.scripting.executeScript({
                        target: { tabId: tab.id },
                        files: ['content_script.js']
                    });

                    // Small delay to allow script to initialize focus tracking
                    await new Promise(r => setTimeout(r, 100));

                    const retryResponse = await sendMessageToTab(tab.id, {
                        action: "SCRIBEFLOW_INJECT",
                        text: text
                    });

                    if (retryResponse && retryResponse.status === true) {
                        console.log("ScribeFlow: Text injected successfully after dynamic injection.");
                        return true;
                    }
                } catch (injectErr) {
                    console.error("ScribeFlow: Failed to dynamically inject content script:", injectErr);
                }
            }

            return false;

        } catch (e) {
            console.error("ScribeFlow Injection Error:", e);
            // This usually happens if the content script isn't loaded on the active tab
            return false;
        }
    }
};
