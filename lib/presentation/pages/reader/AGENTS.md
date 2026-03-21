# Reader Pages — Knowledge Base

**Scope:** `lib/presentation/pages/reader/` (8230 lines across 3 files)

## OVERVIEW

The reader subsystem: text rendering, audiobook UI, and the massive reader_page.dart monolith. This is the highest-complexity area of the project.

## FILES

| File | Lines | Role |
|------|-------|------|
| `reader_page.dart` | **5530** | TXT reader: pagination, chapter nav, settings panel, TTS integration, file import |
| `audiobook_page.dart` | 1774 | Audiobook player UI (cloud TTS playback controls) |
| `audiobook_page_redesign.dart` | 926 | Redesigned audiobook UI variant |

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Pagination / page rendering | `reader_page.dart` — `_TxtPage`, `_buildPageContent()` |
| TTS integration points | `reader_page.dart` — `_startFloatingPlayback()`, double-tap handler |
| Chapter navigation | `reader_page.dart` — table of contents integration |
| Settings panel | `reader_page.dart` — font, brightness, theme controls |
| Audio playback controls | `audiobook_page.dart` — play/pause/stop, progress bar, speed |
| Audiobook page redesign | `audiobook_page_redesign.dart` — alternative UI layout |

## CONVENTIONS

- Reader state lives in the widget itself (not in providers) — this is a known deviation from the rest of the app
- `_TxtPage` / `_TxtLocation` are private model classes within reader_page.dart
- TTS callbacks are wired through `TtsProvider` (Riverpod) but the reader manages the integration logic
- Double-tap gesture on reader center triggers immediate audiobook playback

## ANTI-PATTERNS

- **Do NOT add more features to reader_page.dart** — At 5530 lines, it must be decomposed before adding anything major
- **Do NOT put new reader features in audiobook_page.dart** — Use audiobook_page_redesign.dart as the target for new work
- **Do NOT access SQLite directly from reader** — Go through use case providers

## KNOWN ISSUES

- reader_page.dart mixes: UI rendering, pagination logic, TTS orchestration, file import, settings, and gesture handling — a refactoring priority
- EPUB reading is not implemented here (only TXT via charset_converter)
