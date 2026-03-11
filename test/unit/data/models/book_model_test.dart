import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/book_model.dart';
import 'package:myreader/domain/entities/book.dart';

void main() {
  group('BookModel', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    final testBook = Book(
      id: 'test-id-1',
      title: 'Test Book',
      author: 'Test Author',
      coverPath: '/path/to/cover.jpg',
      epubPath: '/path/to/book.epub',
      totalPages: 300,
      fileSize: 1024000,
      importedAt: testDate,
      lastReadAt: testDate,
      categoryId: 'category-1',
    );

    final testMap = {
      'id': 'test-id-1',
      'title': 'Test Book',
      'author': 'Test Author',
      'cover_path': '/path/to/cover.jpg',
      'epub_path': '/path/to/book.epub',
      'total_pages': 300,
      'file_size': 1024000,
      'imported_at': '2024-01-01T12:00:00.000',
      'last_read_at': '2024-01-01T12:00:00.000',
      'category_id': 'category-1',
    };

    test('should convert from Entity to Model', () {
      final model = BookModel.fromEntity(testBook);

      expect(model.id, testBook.id);
      expect(model.title, testBook.title);
      expect(model.author, testBook.author);
      expect(model.coverPath, testBook.coverPath);
      expect(model.epubPath, testBook.epubPath);
      expect(model.totalPages, testBook.totalPages);
      expect(model.fileSize, testBook.fileSize);
      expect(model.importedAt, testBook.importedAt);
      expect(model.lastReadAt, testBook.lastReadAt);
      expect(model.categoryId, testBook.categoryId);
    });

    test('should convert from Map to Model', () {
      final model = BookModel.fromMap(testMap);

      expect(model.id, 'test-id-1');
      expect(model.title, 'Test Book');
      expect(model.author, 'Test Author');
      expect(model.coverPath, '/path/to/cover.jpg');
      expect(model.epubPath, '/path/to/book.epub');
      expect(model.totalPages, 300);
      expect(model.fileSize, 1024000);
      expect(model.importedAt, testDate);
      expect(model.lastReadAt, testDate);
      expect(model.categoryId, 'category-1');
    });

    test('should convert Model to Map', () {
      final model = BookModel.fromEntity(testBook);
      final map = model.toMap();

      expect(map['id'], 'test-id-1');
      expect(map['title'], 'Test Book');
      expect(map['author'], 'Test Author');
      expect(map['cover_path'], '/path/to/cover.jpg');
      expect(map['epub_path'], '/path/to/book.epub');
      expect(map['total_pages'], 300);
      expect(map['file_size'], 1024000);
      expect(map['category_id'], 'category-1');
    });

    test('should convert Model to Entity', () {
      final model = BookModel.fromMap(testMap);
      final entity = model.toEntity();

      expect(entity.id, testBook.id);
      expect(entity.title, testBook.title);
      expect(entity.author, testBook.author);
      expect(entity.categoryId, testBook.categoryId);
    });

    test('should handle null optional fields', () {
      final bookWithNulls = Book(
        id: 'test-id-2',
        title: 'Book Without Optionals',
        epubPath: '/path/to/book.epub',
        fileSize: 1024,
        importedAt: testDate,
      );

      final model = BookModel.fromEntity(bookWithNulls);
      final map = model.toMap();
      final entity = model.toEntity();

      expect(model.author, isNull);
      expect(model.coverPath, isNull);
      expect(model.totalPages, isNull);
      expect(model.lastReadAt, isNull);
      expect(model.categoryId, isNull);
      expect(map['author'], isNull);
      expect(entity.author, isNull);
    });
  });
}
