// ScribeFlow Content Script
// Tracks the last focused mutable element to allow injection even after focus loss.

let lastFocusedElement = null;

// Listen for focus events to track the active element
document.addEventListener('focus', (event) => {
    if (isMutable(event.target)) {
        lastFocusedElement = event.target;
        // console.log("ScribeFlow: Tracked focus on:", event.target);
    }
}, true); // Use capture phase to catch all focus events

// Also listen for click/input as backup
document.addEventListener('click', (event) => {
    if (isMutable(event.target)) {
        lastFocusedElement = event.target;
    }
}, true);

document.addEventListener('input', (event) => {
    if (isMutable(event.target)) {
        lastFocusedElement = event.target;
    }
}, true);


function isMutable(el) {
    if (!el) return false;
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') return true;
    if (el.isContentEditable) return true;
    return false;
}

// Listen for messages from the Side Panel
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "SCRIBEFLOW_INJECT") {
        const textToInsert = request.text;

        // Use lastFocusedElement if legitimate, otherwise try document.activeElement
        let target = lastFocusedElement;

        // If lastFocusedElement is gone (removed from DOM) or null, try activeElement
        if (!target || !document.contains(target)) {
            if (isMutable(document.activeElement)) {
                target = document.activeElement;
            }
        }

        if (target) {
            const success = injectText(target, textToInsert);
            sendResponse({ status: success });
        } else {
            console.warn("ScribeFlow: No suitable element to inject into.");
            sendResponse({ status: false, error: "No active field found" });
        }
    }
    return true; // Keep channel open for async response
});

function injectText(el, text) {
    try {
        el.focus(); // Try to refocus

        if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
            const start = el.selectionStart || 0;
            const end = el.selectionEnd || 0;
            const value = el.value || "";

            el.value = value.substring(0, start) + text + value.substring(end);

            el.selectionStart = el.selectionEnd = start + text.length;

            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
        } else if (el.isContentEditable) {
            // Use execCommand for ContentEditable as it handles rich text/cursor best
            document.execCommand('insertText', false, text);
            return true;
        }
    } catch (e) {
        console.error("ScribeFlow Inject Error:", e);
    }
    return false;
}

// console.log("ScribeFlow Content Script Loaded");
