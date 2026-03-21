# Domain Layer — Knowledge Base

**Scope:** `lib/domain/` (15 files across 3 subdirectories)

## OVERVIEW

Clean Architecture domain layer: pure business entities, abstract repository interfaces, and use case classes. No dependencies on Flutter, SQLite, or any framework.

## STRUCTURE

```
domain/
├── entities/          # Business objects (Book, Bookmark, Category, Note, ReadingProgress)
├── repositories/      # Abstract interfaces (BookRepository, BookmarkRepository, etc.)
└── usecases/          # Single-responsibility use cases (GetBooksUseCase, AddBookUseCase, etc.)
```

## CONVENTIONS

- **Entities**: Plain Dart classes, no framework dependencies, `==`/`hashCode` based on `id`
- **Repositories**: Abstract classes with `Future<>` return types, defined in domain, implemented in data layer
- **Use cases**: One class per operation, `call()` method pattern, injected via Riverpod
- **Naming**: `<Action><Entity>UseCase` (e.g., `GetBooksUseCase`, `UpdateReadingProgressUseCase`)
- **Immutability**: All entities are immutable (final fields, no setters)

## ENTITIES

| Entity | Key Fields |
|--------|------------|
| `Book` | id, title, author?, coverPath?, epubPath, totalPages?, fileSize, importedAt, lastReadAt?, categoryId? |
| `Bookmark` | id, bookId, title, cfi?, createdAt |
| `Category` | id, name, color, createdAt, sortOrder |
| `Note` | id, bookId, content, cfi?, textSelection?, color, createdAt, updatedAt |
| `ReadingProgress` | bookId, location, percentage, lastReadAt, readingTimeSeconds |

## REPOSITORY INTERFACES

All repositories follow the same pattern:
```dart
abstract class <Entity>Repository {
  Future<List<Entity>> getAll();
  Future<Entity?> getById(String id);
  Future<void> save(Entity entity);
  Future<void> delete(String id);
  // + domain-specific methods
}
```

## USE CASE PATTERN

```dart
class GetBooksUseCase {
  final BookRepository _repository;
  GetBooksUseCase(this._repository);
  Future<List<Book>> call() async => await _repository.getBooks();
}
```

- Constructor injection via Riverpod providers
- Single public method: `call()`
- No business logic beyond delegation (keep thin)

## ANTI-PATTERNS

- **Do NOT import Flutter/Dart UI packages in domain/** — Pure Dart only
- **Do NOT put implementation details in repository interfaces** — Keep them abstract
- **Do NOT add framework-specific annotations** — No `@JsonSerializable`, no `@freezed` here
- **Do NOT skip use cases for direct provider→repository access** — Use case layer exists for a reason

## ADDING NEW DOMAIN OBJECTS

1. Create entity in `entities/`
2. Create abstract repository in `repositories/`
3. Create use cases in `usecases/`
4. Create data model in `data/models/` (with `toEntity()`/`fromEntity()`)
5. Create local datasource in `data/datasources/local/`
6. Create repository impl in `data/repositories/`
7. Wire providers in `core/providers/repository_providers.dart` → `usecase_providers.dart`
