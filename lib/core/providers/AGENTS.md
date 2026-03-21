# Providers — Knowledge Base

**Scope:** `lib/core/providers/` (8 files, ~1400 lines)

## OVERVIEW

All Riverpod providers centralized here. Manages state for books, bookmarks, categories, notes, themes, TTS, and wires up the repository → use case → state notifier chain.

## FILES

| File | Lines | Role |
|------|-------|------|
| `repository_providers.dart` | 76 | DB → DataSource → Repository provider chain |
| `usecase_providers.dart` | 111 | Repository → UseCase provider chain |
| `book_providers.dart` | 165 | `BooksNotifier` (StateNotifier): book list, sort, search, delete |
| `tts_provider.dart` | **745** | `TtsNotifier` (StateNotifier): TTS state machine, cloud/local orchestration |
| `theme_provider.dart` | — | Theme switching state |
| `bookmark_providers.dart` | — | Bookmark CRUD state |
| `category_providers.dart` | — | Category CRUD state |
| `note_providers.dart` | — | Note CRUD state |

## PROVIDER DEPENDENCY CHAIN

```
databaseHelperProvider
  └── *LocalDataSourceProvider
        └── *RepositoryProvider
              └── *UseCaseProvider
                    └── *StateNotifierProvider (book, tts, etc.)
```

## CONVENTIONS

- **Provider naming**: `<name>Provider` for simple, `<name>Notifier` + `<name>Provider` for state notifiers
- **State pattern**: Immutable state class + `copyWith()` + `StateNotifier<State>`
- **Dependency injection**: Always go through providers, never instantiate services/repos directly
- **`ref.read()` vs `ref.watch()`**: Use `read()` inside notifiers for one-shot calls, `watch()` in widgets for reactive rebuilds

## TTS PROVIDER — DEEP DIVE

`tts_provider.dart` is the second-largest provider file (745 lines):

- `TtsAppState`: 20+ state fields (speaking, paused, playback progress, chapter index, voice, loading flags)
- `TtsNotifier`: Manages service callbacks, chapter queue, auto-advance, voice selection, book-voice map persistence
- Key complexity: Chapter queue management, auto-advance between chapters, cloud-to-local fallback coordination
- Voice auto-detection by CJK/Latin character analysis

## ANTI-PATTERNS

- **Do NOT create providers outside this directory** — Centralized location only
- **Do NOT bypass use case providers** — Always go through the chain: repo → usecase → notifier
- **Do NOT use `StateProvider`** — Use `StateNotifierProvider` with proper state classes
- **Do NOT put heavy computation in provider builds** — Use async providers or notifiers for async work

## BOOKS NOTIFIER

`book_providers.dart` contains:
- `BooksState` with sort mode enum (latestAdded, recentRead, progress, title, author)
- `BooksNotifier` with sort algorithm that respects `lastReadAt` fallback to `importedAt`
- `bookByIdProvider` (FutureProvider.family) for single-book lookups
- `booksByCategoryProvider` for filtered views
