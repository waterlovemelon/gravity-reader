import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/remote_catalog/catalog_chapter_model.dart';

void main() {
  group('CatalogChapterModel', () {
    test('parses chapter JSON with navigation fields', () {
      final model = CatalogChapterModel.fromJson({
        'book_id': 'book-1',
        'chapter_id': 'chapter-2',
        'title': 'Middle',
        'content_type': 'text/plain',
        'text': 'Chapter body.',
        'next_chapter_id': 'chapter-3',
        'prev_chapter_id': 'chapter-1',
      });

      expect(model.bookId, 'book-1');
      expect(model.chapterId, 'chapter-2');
      expect(model.title, 'Middle');
      expect(model.contentType, 'text/plain');
      expect(model.text, 'Chapter body.');
      expect(model.nextChapterId, 'chapter-3');
      expect(model.prevChapterId, 'chapter-1');
      expect(model.toEntity().text, 'Chapter body.');
    });

    test('handles null chapter navigation ids', () {
      final model = CatalogChapterModel.fromJson({
        'book_id': 'book-1',
        'chapter_id': 'chapter-1',
        'title': 'First',
        'content_type': 'text/plain',
        'text': 'Opening text.',
        'next_chapter_id': 'chapter-2',
        'prev_chapter_id': null,
      });

      expect(model.prevChapterId, isNull);
      expect(model.toJson()['prev_chapter_id'], isNull);
    });
  });
}
