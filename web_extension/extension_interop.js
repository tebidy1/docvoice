// ScribeFlow Extension Interop
// Handles communication between Flutter (Dart) and Chrome Extensions API

// Define a namespace to avoid collisions
window.scribeflow = {
    // Inject text into the active tab's focused element
    injectTextToActiveTab: async function (text) {
        try {
            // We need to find the active tab first
            const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
            if (!tab) {
                console.error("ScribeFlow: No active tab found.");
                return false;
            }

            // Execute script in the active tab
            // This requires the "scripting" permission in manifest.json
            await chrome.scripting.executeScript({
                target: { tabId: tab.id },
                func: (textToInsert) => {
                    // This function runs IN the context of the web page
                    const activeElement = document.activeElement;

                    if (activeElement) {
                        // Check if it's an input or textarea
                        if (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') {
                            const start = activeElement.selectionStart;
                            const end = activeElement.selectionEnd;
                            const value = activeElement.value;

                            // Insert text at cursor
                            activeElement.value = value.substring(0, start) + textToInsert + value.substring(end);

                            // Move cursor to end of inserted text
                            activeElement.selectionStart = activeElement.selectionEnd = start + textToInsert.length;

                            // Dispatch input event to trigger any listeners (e.g. React/Vue state updates)
                            activeElement.dispatchEvent(new Event('input', { bubbles: true }));
                            return true;
                        }
                        // Check for contenteditable
                        else if (activeElement.isContentEditable) {
                            // Use execCommand for broader compatibility in contenteditable
                            document.execCommand('insertText', false, textToInsert);
                            return true;
                        }
                    }
                    console.warn("ScribeFlow: No suitable active element found to inject text.");
                    return false;
                },
                args: [text]
            });

            console.log("ScribeFlow: Text injected successfully.");
            return true;

        } catch (e) {
            console.error("ScribeFlow Injection Error:", e);
            return false;
        }
    }
};
