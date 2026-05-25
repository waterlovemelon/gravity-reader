import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/remote_catalog/catalog_book_model.dart';

void main() {
  group('CatalogBookSummaryModel', () {
    test('parses book list item JSON and converts to entity', () {
      final model = CatalogBookSummaryModel.fromJson({
        'id': 'book-1',
        'title': 'Remote Book',
        'author': 'Remote Author',
        'description': 'A book from the catalog.',
        'cover_url': 'https://example.com/covers/book-1.jpg',
        'download_url': 'https://example.com/books/book-1.epub',
        'language': 'en',
        'chapter_count': 12,
      });

      expect(model.id, 'book-1');
      expect(model.title, 'Remote Book');
      expect(model.author, 'Remote Author');
      expect(model.description, 'A book from the catalog.');
      expect(model.coverUrl, 'https://example.com/covers/book-1.jpg');
      expect(model.downloadUrl, 'https://example.com/books/book-1.epub');
      expect(model.language, 'en');
      expect(model.chapterCount, 12);

      final entity = model.toEntity();
      expect(entity.id, model.id);
      expect(entity.coverUrl, model.coverUrl);
    });

    test('serializes to API field names', () {
      const model = CatalogBookSummaryModel(
        id: 'book-2',
        title: 'Serializable Book',
        author: 'Author',
        description: 'Description',
        coverUrl: 'https://example.com/cover.jpg',
        downloadUrl: 'https://example.com/book.epub',
        language: 'zh',
        chapterCount: 30,
      );

      expect(model.toJson(), {
        'id': 'book-2',
        'title': 'Serializable Book',
        'author': 'Author',
        'description': 'Description',
        'cover_url': 'https://example.com/cover.jpg',
        'download_url': 'https://example.com/book.epub',
        'language': 'zh',
        'chapter_count': 30,
      });
    });
  });

  group('CatalogBookDetailModel', () {
    test('parses the same catalog book shape for details', () {
      final model = CatalogBookDetailModel.fromJson({
        'id': 'book-3',
        'title': 'Detailed Book',
        'author': 'Detail Author',
        'description': 'Longer description.',
        'cover_url': 'https://example.com/covers/book-3.jpg',
        'download_url': 'https://example.com/books/book-3.epub',
        'language': 'fr',
        'chapter_count': 8,
      });

      expect(model.id, 'book-3');
      expect(model.toEntity().chapterCount, 8);
    });
  });
}
