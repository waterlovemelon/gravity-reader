import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/remote_catalog/catalog_manifest_model.dart';

void main() {
  group('CatalogManifestModel', () {
    test('parses manifest JSON with chapters and converts to entity', () {
      final model = CatalogManifestModel.fromJson({
        'book_id': 'book-1',
        'version': '2026-05-01',
        'title': 'Remote Book',
        'author': 'Remote Author',
        'chapters': [
          {
            'id': 'chapter-1',
            'title': 'Opening',
            'order': 1,
            'word_count': 1200,
          },
          {'id': 'chapter-2', 'title': 'Next', 'order': 2, 'word_count': 1800},
        ],
      });

      expect(model.bookId, 'book-1');
      expect(model.version, '2026-05-01');
      expect(model.title, 'Remote Book');
      expect(model.author, 'Remote Author');
      expect(model.chapters, hasLength(2));
      expect(model.chapters.first.id, 'chapter-1');
      expect(model.chapters.first.wordCount, 1200);

      final entity = model.toEntity();
      expect(entity.bookId, model.bookId);
      expect(entity.chapters.last.order, 2);
    });

    test('serializes to API field names', () {
      const model = CatalogManifestModel(
        bookId: 'book-2',
        version: 'v1',
        title: 'Serializable Manifest',
        author: 'Author',
        chapters: [
          CatalogManifestChapterModel(
            id: 'intro',
            title: 'Intro',
            order: 0,
            wordCount: 500,
          ),
        ],
      );

      expect(model.toJson(), {
        'book_id': 'book-2',
        'version': 'v1',
        'title': 'Serializable Manifest',
        'author': 'Author',
        'chapters': [
          {'id': 'intro', 'title': 'Intro', 'order': 0, 'word_count': 500},
        ],
      });
    });
  });
}
