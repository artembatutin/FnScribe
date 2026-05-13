# Feature 1.2 — Personal Dictionary System

## Overview
The Personal Dictionary System lets FnScribe correct domain-specific transcription errors by applying user-managed spoken→written mappings. It supports:

- Manual entry of custom terminology (names, frameworks, acronyms, etc.)
- Automatic learning from user corrections after injection
- Pre-loaded developer-oriented vocabulary
- Import/export for portability
- Integration with the transcription → injection pipeline

## Core Components
| Component | Location | Responsibility |
|-----------|----------|----------------|
| `DictionaryEntry` | `Domain/Models/DictionaryEntry.swift` | Data model with categories, auto-learn flag, usage stats |
| `DictionaryStore` | `Application/Stores/DictionaryStore.swift` | Actor-based persistence (JSON under `~/Library/Application Support/FnScribe/dictionary.json`) |
| `DictionaryManager` | `Application/Managers/DictionaryManager.swift` | CRUD, filtering, batch import/export, text replacement |
| `CorrectionLearner` | `Infrastructure/Dictionary/CorrectionLearner.swift` | Watches clipboard after injection, infers corrections, feeds manager |
| `DeveloperTermsDatabase` | `Infrastructure/Dictionary/DeveloperTermsDatabase.swift` | Canonical list of ~150 common dev terms |
| `DictionarySettingsView` | `Presentation/Settings/DictionarySettingsView.swift` | Settings tab UI (search, filter, add/edit/delete, import/export) |

## Settings & Environment
`SettingsStore` exposes two toggles:

- `dictionaryEnabled` (default `true`): master switch for applying dictionary replacements.
- `autoLearnCorrections` (default `true`): controls whether `CorrectionLearner` records injected text and creates auto-learned entries.

Both options are surfaced at the top of the Dictionary tab inside Settings.

`AppDependencies` instantiates `DictionaryManager`/`CorrectionLearner`, wires them into `FnScribeApp`, and applies the dictionary before injection (respecting settings). The injected text is recorded for potential learning only when auto-learning is enabled.

## UI/UX Journey
1. Open **Settings → Dictionary**.
2. Toggle the dictionary/auto-learning switches.
3. Use the search bar + category chips (Names, Technical, Acronym, Custom, Correction) to filter entries.
4. Add entries via the “+” button, specifying spoken vs. written forms and category.
5. Edit existing entries using the pencil icon (shows metadata like created/last used & usage count).
6. Load developer terms through the overflow menu to seed baseline vocabulary.
7. Import/export JSON files for backup or sharing.
8. Clear auto-learned entries or wipe the entire dictionary via the overflow menu.

## Auto-Learning Pipeline
1. After auto-injection succeeds, `AppDependencies` calls `CorrectionLearner.recordInjection(_:)` (if enabled).
2. `CorrectionLearner` keeps a timestamped copy of the injected text for ~30 seconds.
3. A clipboard monitor polls every 0.5s; if the user copies edited text that resembles the original, it calculates similarity and confidence.
4. High-confidence single-word corrections produce `CorrectionPair`s (original vs corrected) that are added to the dictionary with category `.correction`/`isAutoLearned = true`.
5. `DictionaryManager` persists the new entry and updates UI counts.

## Developer Terms
`DeveloperTermsDatabase` groups entries into categories (frameworks, acronyms, platforms, tools, languages, common phrases). Loading them is idempotent—existing spoken forms are not duplicated.

## Import/Export Format
- Stored as prettified JSON array of `DictionaryEntry` objects.
- Import supports merge mode (default) to avoid overwriting local entries.
- Export writes to the user-selected location via `NSSavePanel`.

Example payload:
```json
[
  {
    "id": "8B7F...",
    "spokenForm": "super base",
    "writtenForm": "Supabase",
    "category": "custom",
    "isAutoLearned": false,
    "useCount": 0,
    "createdAt": "2026-02-02T21:05:00Z",
    "lastUsedAt": null
  }
]
```

## Text Processing Behavior
- Entries are sorted by descending spoken-form length before replacement to avoid partial overlaps.
- Replacement uses word-boundary regex to avoid mid-word mutations.
- Successful replacements increment `useCount` and update `lastUsedAt`.

## Persistence Notes
- The backing file lives at `~/Library/Application Support/FnScribe/dictionary.json`.
- The actor cache keeps entries in-memory; all mutations go through `DictionaryStore.save(_:)` to remain consistent.

## Extensibility Ideas
- Add localization to the settings UI/help text.
- Surface per-entry statistics (e.g., last IDE used) within the UI.
- Enable bulk editing (CSV import) or remote sync.
- Provide conflict resolution UI for duplicate spoken forms.

This document captures the current implementation; update it when extending the dictionary system or integrating with new pipelines (e.g., streaming transcription).
