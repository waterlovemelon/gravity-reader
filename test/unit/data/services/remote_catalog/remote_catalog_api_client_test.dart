import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/remote_catalog/remote_catalog_api_client.dart';

void main() {
  group('RemoteCatalogApiClient', () {
    late _FakeTransport transport;
    late RemoteCatalogApiClient client;

    setUp(() {
      transport = _FakeTransport();
      client = RemoteCatalogApiClient(
        baseUrl: Uri.parse('https://api.example.com/v1/'),
        transport: transport.get,
      );
    });

    test('builds URL for book list with query parameters', () async {
      transport.nextResponse = jsonEncode({
        'data': [
          {
            'id': 'book-1',
            'title': 'Remote Book',
            'author': 'Author',
            'description': 'Description',
            'cover_url': 'https://example.com/cover.jpg',
            'download_url': 'https://example.com/book.epub',
            'language': 'en',
            'chapter_count': 3,
          },
        ],
      });

      final books = await client.fetchBooks(
        language: 'en',
        page: 2,
        pageSize: 24,
      );

      expect(books, hasLength(1));
      expect(
        transport.lastUri.toString(),
        'https://api.example.com/v1/books?language=en&page=2&page_size=24',
      );
    });

    test(
      'builds encoded URLs for detail manifest and chapter endpoints',
      () async {
        transport.nextResponse = jsonEncode({
          'data': {
            'id': 'book/1',
            'title': 'Remote Book',
            'author': 'Author',
            'description': 'Description',
            'cover_url': 'https://example.com/cover.jpg',
            'download_url': 'https://example.com/book.epub',
            'language': 'en',
            'chapter_count': 3,
          },
        });
        await client.fetchBookDetail('book/1');
        expect(
          transport.lastUri.toString(),
          'https://api.example.com/v1/books/book%2F1',
        );

        transport.nextResponse = jsonEncode({
          'data': {
            'book_id': 'book/1',
            'version': 'v1',
            'title': 'Remote Book',
            'author': 'Author',
            'chapters': [],
          },
        });
        await client.fetchManifest('book/1');
        expect(
          transport.lastUri.toString(),
          'https://api.example.com/v1/books/book%2F1/manifest',
        );

        transport.nextResponse = jsonEncode({
          'data': {
            'book_id': 'book/1',
            'chapter_id': 'chapter 1',
            'title': 'Chapter',
            'content_type': 'text/plain',
            'text': 'Body',
            'next_chapter_id': null,
            'prev_chapter_id': null,
          },
        });
        await client.fetchChapter('book/1', 'chapter 1');
        expect(
          transport.lastUri.toString(),
          'https://api.example.com/v1/books/book%2F1/chapters/chapter%201',
        );
      },
    );

    test('throws for non-success responses', () async {
      transport.nextStatusCode = 500;
      transport.nextResponse = '{"error":"nope"}';

      expect(
        () => client.fetchBooks(),
        throwsA(isA<RemoteCatalogApiException>()),
      );
    });
  });
}

class _FakeTransport {
  Uri? _lastUri;
  String nextResponse = '{}';
  int nextStatusCode = 200;

  Uri get lastUri => _lastUri!;

  Future<RemoteCatalogResponse> get(Uri uri) async {
    _lastUri = uri;
    return RemoteCatalogResponse(
      statusCode: nextStatusCode,
      body: nextResponse,
    );
  }
}
