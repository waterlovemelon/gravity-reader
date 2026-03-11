import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/note.dart';
import 'package:myreader/domain/entities/bookmark.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/domain/entities/category.dart';

class SampleData {
  static final testDate = DateTime(2024, 1, 1, 12, 0, 0);

  static final sampleBook = Book(
    id: 'book-1',
    title: 'Sample Book',
    author: 'Sample Author',
    coverPath: '/path/to/cover.jpg',
    epubPath: '/path/to/book.epub',
    totalPages: 300,
    fileSize: 1024000,
    importedAt: testDate,
    lastReadAt: testDate,
    categoryId: 'category-1',
  );

  static final sampleBooks = [
    sampleBook,
    Book(
      id: 'book-2',
      title: 'Another Book',
      author: 'Another Author',
      epubPath: '/path/to/book2.epub',
      fileSize: 2048000,
      importedAt: testDate,
      categoryId: 'category-2',
    ),
    Book(
      id: 'book-3',
      title: 'Third Book',
      epubPath: '/path/to/book3.epub',
      fileSize: 512000,
      importedAt: testDate,
    ),
  ];

  static final sampleNote = Note(
    id: 'note-1',
    bookId: 'book-1',
    content: 'This is a sample note',
    cfi: 'epubcfi(/6/4[chapter1]!/4/2/1:0)',
    textSelection: 'Selected text',
    color: 1,
    createdAt: testDate,
    updatedAt: testDate,
  );

  static final sampleNotes = [
    sampleNote,
    Note(
      id: 'note-2',
      bookId: 'book-1',
      content: 'Another note',
      color: 2,
      createdAt: testDate,
      updatedAt: testDate,
    ),
  ];

  static final sampleBookmark = Bookmark(
    id: 'bookmark-1',
    bookId: 'book-1',
    title: 'Chapter 5',
    cfi: 'epubcfi(/6/4[chapter5]!/4/2/1:0)',
    createdAt: testDate,
  );

  static final sampleBookmarks = [
    sampleBookmark,
    Bookmark(
      id: 'bookmark-2',
      bookId: 'book-1',
      title: 'Chapter 10',
      createdAt: testDate,
    ),
  ];

  static final sampleReadingProgress = ReadingProgress(
    bookId: 'book-1',
    location: 'epubcfi(/6/4[chapter5]!/4/2/1:50)',
    percentage: 0.45,
    lastReadAt: testDate,
    readingTimeSeconds: 3600,
  );

  static final sampleCategory = Category(
    id: 'category-1',
    name: 'Fiction',
    color: 2,
    createdAt: testDate,
    sortOrder: 1,
  );

  static final sampleCategories = [
    sampleCategory,
    Category(
      id: 'category-2',
      name: 'Non-Fiction',
      color: 3,
      createdAt: testDate,
      sortOrder: 2,
    ),
    Category(
      id: 'category-3',
      name: 'Science',
      color: 1,
      createdAt: testDate,
      sortOrder: 3,
    ),
  ];
}
