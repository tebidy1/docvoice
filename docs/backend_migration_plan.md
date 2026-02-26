# Docvoice AI Brain Refactoring: Backend Migration Plan (Phase 3)

## Document Overview
This document outlines the state of the Docvoice AI Brain refactoring and details the requirements for **Phase 3**, which transfers the ownership of AI Prompt management from the client-side applications (Flutter Mobile, Web, Desktop, Extension) to the Backend Server. 

This guide is intended for the Backend Development Team to implement the necessary API changes to support a centralized, dynamic prompt management system.

---

## What We Have Accomplished So Far (Phases 1 & 2)

### Phase 1: Client-Side Core Refactoring
We successfully eliminated the fragmented spaghetti code where AI processing logic and prompts were duplicated across multiple platforms.
- **Centralized Prompts:** All hardcoded instructions (Prompts) logic has been moved into a single source of truth on the client: `lib/core/ai/ai_prompt_constants.dart`.
- **Text Processing Core:** Created `TextProcessingService` to handle advanced text manipulation. We successfully fixed the critical "Smart Copy" data loss bug where entire lines were being deleted instead of just the placeholder tokens.
- **Unified AI Service:** Created `AIProcessingService` as the unified gateway for all AI Backend communications (`/audio/process` and `/audio/analyze`), deprecating old scattered Gemini services.

### Phase 2: UI Decoupling
- **Dumb Components:** The UI components (Mobile Editor, Desktop Editor, Web Extension Editor) no longer process AI logic. They simply call the pure functions from `TextProcessingService` and `AIProcessingService`.
- **Animation Sync:** We decoupled the extraction (Groq STT) from the formatting (Gemini AI). The raw transcript now immediately appears in the "Source Text" field. The UI's loading overlay (`ProcessingOverlay`) perfectly syncs with the transcription phase and the subsequent template generation phase.

**Current Architecture:**
User Records -> Groq STT (`/audio/transcribe`) -> Raw Text -> User Selects Template -> Client Appends Client-Side Prompts -> Gemini (`/audio/process`) -> Final Note.

---

## Phase 3 Requirements: The Backend Migration

### Why Phase 3?
Currently, if the medical team wants to tweak the master prompt (e.g., instructing the AI to "always bold medication names"), we have to release a new version of the Mobile App, Desktop App, and Web Extension. 
**Goal:** The Backend should supply the prompts. The client apps will simply download the prompts on startup or fetch them dynamically, allowing instantaneous global updates without App Store releases.

### 1. Database Adjustments (Backend)

The backend needs a way to store and manage Prompts.
Create a new table (e.g., `ai_prompts`) with the following suggested schema:

| Column Name | Type | Description |
| :--- | :--- | :--- |
| `id` | INT | Primary Key |
| `key` | VARCHAR | Unique identifier (e.g., `MASTER_PROMPT`, `SUMMARIZATION_PROMPT`) |
| `content` | TEXT | The actual prompt instructions |
| `version` | INT | For caching/updating |
| `description` | VARCHAR| Internal description for admins |

### 2. New API Endpoint (Backend)

**Endpoint:** `GET /api/ai/prompts`
**Purpose:** Returns the latest AI prompts to the client application.

**Response payload example:**
```json
{
  "status": true,
  "code": 200,
  "message": "Success",
  "payload": {
    "version": 1,
    "prompts": {
      "MASTER_PROMPT": "You are an expert medical scribe...\n...",
      "SUGGESTION_PROMPT": "Analyze the following transcript and suggest missing fields...",
      "SUMMARIZATION_PROMPT": "Summarize the following patient interaction in 2 sentences."
    }
  }
}
```

### 3. Modifying Existing Endpoints (Backend)

Currently, the client sends `global_prompt` within the body of `POST /api/audio/process`. 

**In Phase 3, you have two architectural choices:**

**Choice A: Server-Side Injection (Recommended)**
The Backend handles the prompt injection. 
1. The client sends **only** the `transcript`, `macro_context`, and `specialty`.
2. The Backend intercepts the request, pulls the `MASTER_PROMPT` from the backend database, constructs the final prompt string, and queries Gemini.
*Pros: Maximum security, smallest payload, no client updating logic needed.*

**Choice B: Client-Side Fetch & Send**
1. The client fetches the prompts from `GET /api/ai/prompts` on startup and caches them.
2. The client continues to send `global_prompt` in `POST /api/audio/process`, but uses the downloaded prompt instead of the hardcoded local one.
*Pros: Easier tracing on the client side, but larger payloads.*

### 4. Admin Dashboard Implementation

The Backend team needs to develop a UI page in the Admin Dashboard:
- **View Prompts:** List all active Prompts.
- **Edit Prompts:** A large text area to modify the instructions.
- **History/Rollback:** (Optional but recommended) Track changes so safe rollbacks are possible if an AI prompt causes degraded performance.

---

## Action Items for Backend Team
1. [ ] Discuss and select **Choice A** or **Choice B** for prompt injection.
2. [ ] Create database schema for `ai_prompts`.
3. [ ] Build the Administrator Dashboard UI to read/write prompts to the database.
4. [ ] Build the `GET /api/ai/prompts` endpoint (if choosing Choice B or for client caching).
5. [ ] Update `/api/audio/process` logic to pull from the database (if choosing Choice A).
6. [ ] Notify the Frontend/Flutter developer when the endpoints are ready on the staging server so they can connect `AIProcessingService` to them.

## Action Items for Client/Flutter Developer (Once API is ready)
1. Delete hardcoded prompts from `lib/core/ai/ai_prompt_constants.dart`.
2. Update `AIProcessingService` to fetch/use the backend prompts.
