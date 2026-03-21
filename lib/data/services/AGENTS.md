# Services — Knowledge Base

**Scope:** `lib/data/services/` (4 files, ~2800 lines)

## OVERVIEW

Business services that don't fit neatly into repositories: TTS audio engine, text-to-speech cloud integration, TXT file parsing, theme persistence.

## FILES

| File | Lines | Role |
|------|-------|------|
| `tts_service.dart` | **1978** | Core TTS engine: cloud API + local fallback, audio playback via just_audio, chapter queue |
| `txt_parser.dart` | — | TXT file parsing, chapter detection, encoding conversion |
| `txt_import_cache_service.dart` | — | Caches parsed TXT content for performance |
| `theme_preferences_service.dart` | — | Persists theme selection via SharedPreferences |

## TTS SERVICE — DEEP DIVE

The largest service file (1978 lines). Architecture:

```
TtsService
  ├── _TtsEngine: cloud | local | none
  ├── Cloud flow: HTTP GET → save audio file → just_audio playback
  ├── Local flow: MethodChannel → iOS/Android native TTS
  ├── Chapter queue: _CloudChunkPlan for multi-chapter seamless playback
  ├── Callbacks: state, completion, progress, playbackOffset, chapterChanged
  └── Voice management: fetch voices from cloud API, locale-based filtering
```

### Cloud TTS Flow
1. Text → chunk into `_CloudChunkPlan` items
2. `GET /api/text-to-speech?text=...&voice=...` → returns audio bytes
3. Save to temp file → `just_audio.AudioPlayer.setFilePath()`
4. On timeout/error → fall back to local `MethodChannel` TTS
5. Cooldown period (30s default) before retrying cloud

### Key Types
- `TtsState`: playing, stopped, paused
- `TtsVoice`: voice metadata (value, label, locale, gender, names, traits)
- `TtsMediaContext`: book metadata for media notification (just_audio_background)

## ANTI-PATTERNS

- **Do NOT call TtsService directly from widgets** — Always go through `ttsProvider` (TtsNotifier)
- **Do NOT modify cloud API contract without updating docs/edge-tts-architecture.md**
- **Do NOT change timeout/retry constants in code** — Use `dart_defines.local.json`

## TXT PARSER

Handles TXT book import:
- Character encoding detection and conversion (via charset_converter)
- Chapter splitting heuristics (Chinese chapter patterns: 第X章, 第X节)
- Content caching for large file performance

## CONFIG

TTS behavior controlled via environment:
- `TTS_BASE_URL` — Cloud TTS gateway URL
- `TTS_TOKEN` — Auth token
- `TTS_VOICE` — Default voice (zh-CN XiaoxiaoNeural)
- `TTS_CLOUD_TIMEOUT_MS` — Cloud timeout (default 8000)
- `TTS_CLOUD_RETRY_COOLDOWN_MS` — Retry cooldown (default 30000)
