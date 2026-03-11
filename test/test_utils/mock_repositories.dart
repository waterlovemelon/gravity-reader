import 'package:mocktail/mocktail.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/note.dart';
import 'package:myreader/domain/entities/bookmark.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/domain/repositories/book_repository.dart';
import 'package:myreader/domain/repositories/note_repository.dart';
import 'package:myreader/domain/repositories/bookmark_repository.dart';
import 'package:myreader/domain/repositories/reading_repository.dart';
import 'package:myreader/domain/repositories/category_repository.dart';
import 'package:myreader/data/models/book_model.dart';
import 'package:myreader/data/models/note_model.dart';
import 'package:myreader/data/models/bookmark_model.dart';
import 'package:myreader/data/models/reading_progress_model.dart';
import 'package:myreader/data/models/category_model.dart';

class MockBookRepository extends Mock implements BookRepository {}

class MockNoteRepository extends Mock implements NoteRepository {}

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockReadingRepository extends Mock implements ReadingRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeBook extends Fake implements Book {}

class FakeNote extends Fake implements Note {}

class FakeBookmark extends Fake implements Bookmark {}

class FakeReadingProgress extends Fake implements ReadingProgress {}

class FakeCategory extends Fake implements Category {}

class FakeBookModel extends Fake implements BookModel {}

class FakeNoteModel extends Fake implements NoteModel {}

class FakeBookmarkModel extends Fake implements BookmarkModel {}

class FakeReadingProgressModel extends Fake implements ReadingProgressModel {}

class FakeCategoryModel extends Fake implements CategoryModel {}

void registerFallbackValues() {
  registerFallbackValue(FakeBook());
  registerFallbackValue(FakeNote());
  registerFallbackValue(FakeBookmark());
  registerFallbackValue(FakeReadingProgress());
  registerFallbackValue(FakeCategory());
  registerFallbackValue(FakeBookModel());
  registerFallbackValue(FakeNoteModel());
  registerFallbackValue(FakeBookmarkModel());
  registerFallbackValue(FakeReadingProgressModel());
  registerFallbackValue(FakeCategoryModel());
}
