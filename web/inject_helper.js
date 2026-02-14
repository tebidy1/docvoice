// Helper to bridge Flutter and Chrome Extensions API for Injection
window.scribeflow = {
    injectTextToActiveTab: async function (text) {
        console.log("Attempting to inject text via Message Passing:", text.substring(0, 20) + "...");
        try {
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            if (!tab) {
                console.error("No active tab found");
                return false;
            }

            // Send Message to Content Script
            // The content script tracks the last focused element and will handle insertion.
            const response = await chrome.tabs.sendMessage(tab.id, {
                action: "SCRIBEFLOW_INJECT",
                text: text
            });

            if (response && response.status === true) {
                return true;
            }
            return false;

        } catch (e) {
            console.error("Injection Message Failed:", e);
            return false;
        }
    }
};
