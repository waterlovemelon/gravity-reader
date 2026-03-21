# Data Layer — Knowledge Base

**Scope:** `lib/data/` (20 files across 5 subdirectories)

## OVERVIEW

Clean Architecture data layer: SQLite database, local data sources, data models (with entity mapping), repository implementations, and business services.

## STRUCTURE

```
data/
├── database/              # SQLite singleton (DatabaseHelper)
├── datasources/local/     # Raw SQL queries per entity
├── models/                # Data models with toMap()/fromMap() + toEntity()/fromEntity()
├── repositories/          # Repository implementations (delegate to datasources)
└── services/              # TTS engine, TXT parser, cache, theme prefs
```

## CONVENTIONS

- **Models**: `toMap()` / `fromMap()` for SQLite, `toEntity()` / `fromEntity()` for domain conversion
- **Data sources**: One class per entity, takes `DatabaseHelper` in constructor, returns models
- **Repository impls**: Thin delegation layer — datasource calls + model→entity conversion
- **Database**: Singleton `DatabaseHelper.instance`, version-based migrations in `_onUpgrade`
- **IDs**: String-based (timestamp-based or UUID), not auto-increment integers (except reading_sessions)

## DATABASE SCHEMA

| Table | Primary Key | Notable Fields |
|-------|-------------|----------------|
| `books` | `id TEXT` | title, epub_path, cover_path, category_id (FK → categories) |
| `notes` | `id TEXT` | book_id (FK → books, CASCADE), content, cfi, text_selection |
| `bookmarks` | `id TEXT` | book_id (FK → books, CASCADE), title, cfi |
| `reading_progress` | `book_id TEXT` | location, percentage, reading_time_seconds |
| `categories` | `id TEXT` | name, color, sort_order |
| `reading_sessions` | `INTEGER AUTOINCREMENT` | book_id, start_time, end_time, duration_seconds |

Indexes: `idx_books_category`, `idx_books_title`, `idx_notes_book`, `idx_bookmarks_book`, `idx_sessions_book`

## MIGRATION PATTERN

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Check if column exists before ALTER
    final columns = await db.rawQuery("PRAGMA table_info(books)");
    if (!columns.any((c) => c['name'] == 'new_column')) {
      await db.execute('ALTER TABLE books ADD COLUMN new_column TEXT');
    }
  }
}
```

Always bump `databaseVersion` in `core/constants/app_constants.dart`.

## DATA SOURCE PATTERN

```dart
class BookLocalDataSource {
  final DatabaseHelper _dbHelper;
  BookLocalDataSource(this._dbHelper);

  Future<List<BookModel>> getBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query('books');
    return maps.map((m) => BookModel.fromMap(m)).toList();
  }
  // ...
}
```

## ANTI-PATTERNS

- **Do NOT write raw SQL in repositories** — Data sources own all SQL
- **Do NOT skip model→entity conversion** — Repositories return domain entities, not models
- **Do NOT use cascading deletes without thinking** — books deletion cascades to notes/bookmarks/progress
- **Do NOT modify DB schema without migration** — Always use `_onUpgrade` + version bump
- **Do NOT put service logic in data sources** — TTS, TXT parsing belong in services/

## WIRING

Provider chain (in `core/providers/repository_providers.dart`):
```
databaseHelperProvider → bookLocalDataSourceProvider → bookRepositoryProvider
```

Use case wiring (in `core/providers/usecase_providers.dart`):
```
bookRepositoryProvider → getBooksUseCaseProvider
```
