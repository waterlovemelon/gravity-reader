# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-21
**Commit:** a9e8e36
**Branch:** develop

## OVERVIEW

Gravity Reader — Flutter cross-platform ebook reader (iOS + Android). Supports EPUB/TXT formats with built-in audiobook/TTS (cloud Edge-TTS + local fallback). Clean Architecture with Riverpod state management and SQLite storage.

## STRUCTURE

```
gravity-reader/
├── lib/
│   ├── main.dart                          # Entry: ProviderScope → MaterialApp → MainNavigationPage
│   ├── core/                              # Infrastructure: constants, models, providers, router, theme, utils
│   ├── data/                              # Data layer: SQLite DB, local datasources, models, repos, services
│   ├── domain/                            # Domain layer: entities, abstract repositories, use cases
│   ├── flureadium_integration/            # EPUB parser (STUB — returns hardcoded chapters, not real parsing)
│   └── presentation/                      # UI: pages (reader, bookshelf, profile), widgets
├── test/                                  # Unit + widget tests (models, repos, use cases, txt_parser)
├── integration_test/                      # Integration test config only
├── assets/images/book_placeholders/       # Default cover images
├── design-system/                         # UI design reference (external tool output)
├── docs/                                  # edge-tts-architecture.md (TTS gateway design doc)
├── env/                                   # dart_defines.example.json / .local.json (TTS config)
├── android/, ios/, web/, linux/, macos/, windows/  # Platform runners
└── skills/                                # External skill assets (ui-ux-pro-max)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new book format support | `lib/domain/entities/` + `lib/data/models/` | Add entity + model + datasource + repo + usecase |
| Modify reader UI | `lib/presentation/pages/reader/reader_page.dart` | **5530 lines** — biggest file, handle with care |
| TTS / audiobook changes | `lib/data/services/tts_service.dart` + `lib/core/providers/tts_provider.dart` | Cloud-first + local fallback architecture |
| Database schema changes | `lib/data/database/database_helper.dart` | Add migration in `_onUpgrade`, bump `databaseVersion` in `app_constants.dart` |
| Riverpod providers | `lib/core/providers/` | All providers centralized here |
| Use case contracts | `lib/domain/usecases/` | One class per use case, `call()` method pattern |
| Repository pattern | `lib/domain/repositories/` (abstract) → `lib/data/repositories/` (impl) | Interface in domain, impl in data |
| TTS architecture design | `docs/edge-tts-architecture.md` | Edge-TTS gateway design, phased rollout plan |
| EPUB parsing | `lib/flureadium_integration/epub_parser.dart` | **STUB**: returns hardcoded chapters 1-10, no real EPUB parsing |
| Run commands | See COMMANDS below | |

## CODE MAP

| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `main()` | Function | `lib/main.dart` | App entry, JustAudioBackground init |
| `MyReaderApp` | Widget | `lib/main.dart` | MaterialApp with Riverpod Consumer, theme + routing |
| `MainNavigationPage` | Widget | `lib/presentation/pages/main_navigation_page.dart` | Bottom nav: 阅读/书架/书友/我的 |
| `ReaderPage` | Widget | `lib/presentation/pages/reader/reader_page.dart` | TXT reader with pagination, TTS, settings |
| `BookshelfPage` | Widget | `lib/presentation/pages/bookshelf/bookshelf_page.dart` | Book grid, import, sort, search |
| `TtsNotifier` | StateNotifier | `lib/core/providers/tts_provider.dart` | TTS state machine, cloud/local orchestration |
| `TtsService` | Service | `lib/data/services/tts_service.dart` | Audio playback engine (just_audio + cloud API) |
| `DatabaseHelper` | Singleton | `lib/data/database/database_helper.dart` | SQLite init, migrations, schema |
| `BooksNotifier` | StateNotifier | `lib/core/providers/book_providers.dart` | Book list state, sort modes |
| `Book` | Entity | `lib/domain/entities/book.dart` | Core book entity (id, title, epubPath, etc.) |

## CONVENTIONS

- **Clean Architecture**: domain (entities + repos + usecases) → data (models + datasources + repos + services) → presentation (pages + widgets)
- **Riverpod StateNotifier pattern**: `StateNotifier<ImmutableState>` + `copyWith()` for all state classes
- **Use case pattern**: Single-class-per-use-case with `call()` method, injected via Riverpod providers
- **Provider hierarchy**: `repository_providers` → `usecase_providers` → `book_providers`/`tts_provider` (presentation providers read from usecase providers)
- **Package name**: `myreader` (not `gravity_reader` in imports)
- **Chinese UI**: App labels are in Chinese (阅读, 书架, 书友, 我的)
- **TTS config**: via `dart-define-from-file=env/dart_defines.local.json`, not `.env`

## ANTI-PATTERNS (THIS PROJECT)

- **Do NOT add Flureadium as a Flutter dependency** — `flureadium_integration/` is a stub. Real EPUB reading is via the TXT parser or future native integration
- **Do NOT put business logic in widgets** — Use cases exist for every operation; go through providers
- **Do NOT modify the SQLite schema without a migration** — Always add to `_onUpgrade` and bump `databaseVersion`
- **Do NOT hardcode TTS URLs/tokens** — Use `dart_defines.local.json` with `String.fromEnvironment`
- **Do NOT create new provider files outside `lib/core/providers/`** — All providers are centralized
- **reader_page.dart is 5530 lines** — Resist growing it further; extract widgets/services instead

## UNIQUE STYLES

- **Cloud-first TTS with graceful fallback**: Cloud TTS → timeout (8s) → local TTS → cooldown (30s) → retry cloud
- **Book-per-voice assignment**: Each book can have a different TTS voice, persisted via SharedPreferences
- **Auto-detect language**: TTS auto-selects voice locale (zh/ja/ko/en) based on text character analysis
- **Chapter queue system**: TTS chapters are queued for seamless multi-chapter playback
- **Double-tap to listen**: Double-tapping reader center region starts audiobook playback immediately

## COMMANDS

```bash
# Install dependencies
flutter pub get

# Run (iOS)
flutter run -d ios --dart-define-from-file=env/dart_defines.local.json

# Run (Android)
flutter run -d android --dart-define-from-file=env/dart_defines.local.json

# Analyze code
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Build iOS
flutter build ios --dart-define-from-file=env/dart_defines.local.json
```

## NOTES

- **EPUB support is incomplete**: `EpubParserImpl` returns hardcoded chapters. Real EPUB parsing requires a new implementation
- **reader_page.dart is a monolith**: 5530 lines — the #1 refactoring target. Contains reader logic, TTS integration, settings UI, pagination, text import
- **tts_provider.dart is 745 lines**: Second-largest provider, manages complex TTS state machine
- **tts_service.dart is 1978 lines**: Handles cloud API calls, audio playback, chapter queue, voice management
- **Tests are partial**: Model tests and use case tests exist; no widget tests for reader/bookshelf, no integration tests
- **Platform runners present**: android/, ios/, web/, linux/, macos/, windows/ — but primary targets are iOS + Android
- **design-system/ and skills/ are external tool outputs**, not source code
