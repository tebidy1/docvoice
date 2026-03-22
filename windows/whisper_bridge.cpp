// ============================================================
// whisper_bridge.cpp — C-ABI wrapper for whisper.cpp on Windows
// ============================================================
// Provides a clean FFI interface for Dart to call whisper.cpp
// functions. All functions are guarded by try/catch to prevent
// silent Isolate crashes.
// ============================================================

#include <string>
#include <mutex>
#include <thread>
#include <algorithm>
#include <cstring>

// whisper.h is resolved via include directories set in the build script
#include "whisper.h"

#ifdef _WIN32
#define EXPORT extern "C" __declspec(dllexport)
#else
#define EXPORT extern "C" __attribute__((visibility("default")))
#endif

// Global state — protected by a mutex for thread safety
static struct whisper_context* g_ctx = nullptr;
static std::mutex g_mutex;

// Persistent buffer for returning strings to Dart
static std::string g_result_buffer;

// ────────────────────────────────────────────────────
// whisper_bridge_init
// ────────────────────────────────────────────────────
// Loads the model from the given file path.
// Returns 1 on success, 0 on failure.
EXPORT int whisper_bridge_init(const char* model_path) {
    try {
        std::lock_guard<std::mutex> lock(g_mutex);

        // Free existing context if any
        if (g_ctx != nullptr) {
            whisper_free(g_ctx);
            g_ctx = nullptr;
        }

        struct whisper_context_params cparams = whisper_context_default_params();
        cparams.use_gpu = false;      // CPU-only for maximum compatibility
        cparams.flash_attn = false;   // Flash attention requires GPU — hangs on CPU-only

        g_ctx = whisper_init_from_file_with_params(model_path, cparams);
        if (g_ctx == nullptr) {
            return 0; // Failed to load model
        }

        return 1; // Success
    } catch (...) {
        g_ctx = nullptr;
        return 0;
    }
}

// ────────────────────────────────────────────────────
// whisper_bridge_transcribe
// ────────────────────────────────────────────────────
// Transcribes raw 16kHz float32 PCM audio.
// 
// Parameters:
//   samples      - pointer to float32 PCM data (mono, 16kHz)
//   num_samples  - number of float samples
//   language     - language code (e.g., "en")
//   prompt       - initial prompt for context continuity (can be NULL)
//
// Returns: pointer to null-terminated transcription string.
//          Returns empty string on error (never NULL).
EXPORT const char* whisper_bridge_transcribe(
    const float* samples,
    int num_samples,
    const char* language,
    const char* prompt
) {
    try {
        std::lock_guard<std::mutex> lock(g_mutex);

        if (g_ctx == nullptr || samples == nullptr || num_samples <= 0) {
            g_result_buffer = "";
            return g_result_buffer.c_str();
        }

        // Configure full parameters for greedy decoding
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

        params.language = (language && strlen(language) > 0) ? language : "en";
        params.translate = false;
        params.no_context = false;
        params.single_segment = false;
        params.print_special = false;
        params.print_progress = false;
        params.print_realtime = false;
        params.print_timestamps = false;
        params.suppress_blank = true;
        params.suppress_nst = true;

        // Use all physical cores available, capped at 8 to avoid over-subscription on HT systems.
        // On i7-1065G7 (4 cores, 8 threads) this gives us 4 physical cores.
        const int hw_threads = static_cast<int>(std::thread::hardware_concurrency());
        params.n_threads = (hw_threads > 0) ? std::min(hw_threads, 8) : 4;

        // Set initial prompt for context continuity
        if (prompt != nullptr && strlen(prompt) > 0) {
            params.initial_prompt = prompt;
        }

        // Run inference
        int result = whisper_full(g_ctx, params, samples, num_samples);
        if (result != 0) {
            g_result_buffer = "";
            return g_result_buffer.c_str();
        }

        // Collect all segments into result
        g_result_buffer.clear();
        int n_segments = whisper_full_n_segments(g_ctx);
        for (int i = 0; i < n_segments; i++) {
            const char* text = whisper_full_get_segment_text(g_ctx, i);
            if (text != nullptr) {
                g_result_buffer += text;
            }
        }

        return g_result_buffer.c_str();
    } catch (...) {
        g_result_buffer = "";
        return g_result_buffer.c_str();
    }
}

// ────────────────────────────────────────────────────
// whisper_bridge_free
// ────────────────────────────────────────────────────
// Releases the model from memory.
EXPORT void whisper_bridge_free() {
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_ctx != nullptr) {
            whisper_free(g_ctx);
            g_ctx = nullptr;
        }
    } catch (...) {
        g_ctx = nullptr;
    }
}

// ────────────────────────────────────────────────────
// whisper_bridge_is_loaded
// ────────────────────────────────────────────────────
// Returns 1 if the model is loaded, 0 otherwise.
EXPORT int whisper_bridge_is_loaded() {
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        return (g_ctx != nullptr) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}
