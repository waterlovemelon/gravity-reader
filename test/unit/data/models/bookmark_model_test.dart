import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/bookmark_model.dart';
import 'package:myreader/domain/entities/bookmark.dart';

void main() {
  group('BookmarkModel', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    final testBookmark = Bookmark(
      id: 'bookmark-1',
      bookId: 'book-1',
      title: 'Chapter 5',
      cfi: 'epubcfi(/6/4[chapter5]!/4/2/1:0)',
      createdAt: testDate,
    );

    final testMap = {
      'id': 'bookmark-1',
      'book_id': 'book-1',
      'title': 'Chapter 5',
      'cfi': 'epubcfi(/6/4[chapter5]!/4/2/1:0)',
      'created_at': '2024-01-01T12:00:00.000',
    };

    test('should convert from Entity to Model', () {
      final model = BookmarkModel.fromEntity(testBookmark);

      expect(model.id, testBookmark.id);
      expect(model.bookId, testBookmark.bookId);
      expect(model.title, testBookmark.title);
      expect(model.cfi, testBookmark.cfi);
      expect(model.createdAt, testBookmark.createdAt);
    });

    test('should convert from Map to Model', () {
      final model = BookmarkModel.fromMap(testMap);

      expect(model.id, 'bookmark-1');
      expect(model.bookId, 'book-1');
      expect(model.title, 'Chapter 5');
      expect(model.cfi, 'epubcfi(/6/4[chapter5]!/4/2/1:0)');
    });

    test('should convert Model to Map', () {
      final model = BookmarkModel.fromEntity(testBookmark);
      final map = model.toMap();

      expect(map['id'], 'bookmark-1');
      expect(map['book_id'], 'book-1');
      expect(map['title'], 'Chapter 5');
    });

    test('should convert Model to Entity', () {
      final model = BookmarkModel.fromMap(testMap);
      final entity = model.toEntity();

      expect(entity.id, testBookmark.id);
      expect(entity.bookId, testBookmark.bookId);
      expect(entity.title, testBookmark.title);
    });

    test('should handle null cfi', () {
      final bookmarkNoCfi = Bookmark(
        id: 'bookmark-2',
        bookId: 'book-1',
        title: 'Start',
        createdAt: testDate,
      );

      final model = BookmarkModel.fromEntity(bookmarkNoCfi);
      final map = model.toMap();

      expect(model.cfi, isNull);
      expect(map['cfi'], isNull);
    });
  });
}
