
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
