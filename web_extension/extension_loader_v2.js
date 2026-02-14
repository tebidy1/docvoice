
// The value below is injected by flutter build, do not touch.
// For extension, we force it to null to avoid SW usage
const serviceWorkerVersion = null;

console.log("[ScribeFlow] Extension Loader Started");

// Force HTML renderer at the global level for newer Flutter versions
window.flutterWebRenderer = "html";
window._flutter = window._flutter || {};
window._flutter.loader = window._flutter.loader || {};
window._flutter.buildConfig = {
    renderer: "html"
};

// Also set the modern configuration object
window.flutterConfiguration = {
    renderer: "html"
};

window.addEventListener('load', function (ev) {
    console.log("[ScribeFlow] Window Loaded. Starting Flutter Loader...");

    // Download main.dart.js
    _flutter.loader.loadEntrypoint({
        serviceWorker: null,
        onEntrypointLoaded: function (engineInitializer) {
            console.log("[ScribeFlow] Entrypoint Loaded. Initializing Engine...");

            engineInitializer.initializeEngine({
                hostElement: document.querySelector('body'),
                renderer: 'html', // FORCE HTML renderer.
                assetBase: './'
            }).then(function (appRunner) {
                console.log("[ScribeFlow] Engine Initialized. Running App...");

                const loading = document.getElementById('loading');
                if (loading) loading.style.display = 'none';

                appRunner.runApp();
                console.log("[ScribeFlow] runApp called successfully.");
            }).catch(err => {
                console.error("[ScribeFlow] Error initializing engine:", err);
            });
        }
    }).catch(err => {
        console.error("[ScribeFlow] Error loading entrypoint:", err);
    });
});

// --- Smart Inject Helper ---
// Expose functions to Flutter via window
window.scribeflow = {
    injectTextToActiveTab: async function (text) {
        console.log("[ScribeFlow] Attempting Smart Inject...");
        try {
            // Get active tab using API
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

            if (!tab) {
                console.warn("[ScribeFlow] No active tab found.");
                return false;
            }

            // Scripting API Injection
            // Requires 'scripting' permission in V3 manifest
            const results = await chrome.scripting.executeScript({
                target: { tabId: tab.id },
                func: (textToInject) => {
                    const activeEl = document.activeElement;

                    // Helper to insert at cursor
                    const insertAtCursor = (field, value) => {
                        if (field.selectionStart || field.selectionStart === 0) {
                            var startPos = field.selectionStart;
                            var endPos = field.selectionEnd;
                            field.value = field.value.substring(0, startPos)
                                + value
                                + field.value.substring(endPos, field.value.length);
                            field.selectionStart = startPos + value.length;
                            field.selectionEnd = startPos + value.length;
                        } else {
                            field.value += value;
                        }
                        // Trigger input event for React/Angular/Vue etc
                        field.dispatchEvent(new Event('input', { bubbles: true }));
                        field.dispatchEvent(new Event('change', { bubbles: true }));
                    };

                    if (activeEl && (activeEl.tagName === 'TEXTAREA' || activeEl.tagName === 'INPUT')) {
                        insertAtCursor(activeEl, textToInject);
                        return true;
                    }
                    else if (activeEl && activeEl.isContentEditable) {
                        // Standard ContentEditable (e.g. Gmail, some EMRs)
                        // document.execCommand is deprecated but still the most reliable way 
                        // to handle complex editors that respect undo stack
                        document.execCommand('insertText', false, textToInject);
                        return true;
                    }

                    return false; // No valid field focused
                },
                args: [text]
            });

            // Check results from injection frame
            if (results && results[0] && results[0].result === true) {
                console.log("[ScribeFlow] Injection successful!");
                return true;
            } else {
                console.log("[ScribeFlow] No focused field detected on page.");
                return false;
            }

        } catch (e) {
            console.error("[ScribeFlow] Injection Error:", e);
            return false;
        }
    }
};
