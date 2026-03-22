# Multimodal AI Feature — lib/features/multimodal_ai/

## What is this?

This folder contains a **self-contained, isolated** feature that processes
medical voice recordings and templates in **one AI request** using Google
Gemini's multimodal capabilities.

Unlike the existing 2-stage pipeline (STT → Backend → Gemini), this feature
sends audio bytes + template text **directly** to `gemini-2.5-flash` in a
single call — no separate transcription step, no backend hop.

---

## Files

| File | Role |
|---|---|
| `multimodal_ai_service.dart` | **Abstract Interface** — the contract UI code depends on |
| `multimodal_ai_result.dart` | **Data Model** — returned by all implementations |
| `ai_studio_multimodal_service.dart` | **AI Studio Impl** — Google AI Studio + API Key (Current) |

---

## Migration Roadmap

```
Phase 1 (NOW)    → AIStudioMultimodalService   — Google AI Studio (API Key)
Phase 2 (TODO)   → VertexAIMultimodalService   — Vertex AI Saudi Region (IAM)
Phase 3 (TODO)   → BackendMultimodalService    — Route through docapi.sootnote.com
```

To add a new provider: create a new Dart file implementing `MultimodalAIService`, 
then change the DI wiring. **Zero UI changes needed.**

---

## How to Remove This Feature Completely

1. Comment out `google_generative_ai` in `pubspec.yaml`
2. Delete this entire folder (`lib/features/multimodal_ai/`)
3. Remove the One-Shot AI button from `inbox_note_detail_view.dart`
4. Run `flutter pub get`

---

## Supported Audio Formats

| Platform | Format | MIME Type |
|---|---|---|
| Windows | WAV | `audio/wav` |
| iOS / macOS | M4A | `audio/m4a` |
| Android | AAC/M4A | `audio/m4a` |
| Web | WebM | `audio/webm` |

> Note: Files must be under 20 MB to use the inline `DataPart` approach.
> Larger files would require the Gemini Files API (not implemented here).
