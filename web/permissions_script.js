document.addEventListener('DOMContentLoaded', function () {
    const btn = document.getElementById('grantBtn');
    if (btn) {
        btn.addEventListener('click', requestMic);
    }

    // Also try automatically on load
    requestMic();
});

async function requestMic() {
    const statusFn = (text, color) => {
        const el = document.getElementById('status');
        if (el) {
            el.innerText = text;
            el.style.color = color || '#666';
        }
    };

    try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        statusFn("✅ Permission Granted! You can close this tab and try recording in the extension again.", "green");

        // Stop tracks to release
        stream.getTracks().forEach(t => t.stop());

        // Optional: Auto-close after 3 seconds
        setTimeout(() => window.close(), 3000);
    } catch (e) {
        console.error(e);
        statusFn("❌ Permission Denied: " + e.message, "red");
    }
}
