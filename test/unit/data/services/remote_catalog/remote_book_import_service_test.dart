import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/remote_catalog/remote_book_import_service.dart';
import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';

void main() {
  group('RemoteBookImportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('remote_book_import_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloads an EPUB and prepares it as a local book', () async {
      final fixture = File('test/books/张居正.epub');
      Uri? requestedUri;
      final service = RemoteBookImportService(
        appDirProvider: () async => tempDir,
        catalogBaseUrl: Uri.parse('https://example.com/api/'),
        downloader: (uri) {
          requestedUri = uri;
          return fixture.readAsBytes();
        },
        epubImportCacheService: EpubImportCacheService(
          appDirProvider: () async => tempDir,
        ),
        idProvider: (_) => 'remote_zhang_juzheng',
        nowProvider: () => DateTime(2026, 5, 21, 12),
        placeholderCoverBytesProvider: (_) async => null,
      );

      final book = await service.importFromCatalog(
        const CatalogBookSummary(
          id: 'zhang-juzheng',
          title: '张居正',
          author: '熊召政',
          description: '历史小说',
          coverUrl: '',
          downloadUrl: '/v1/catalog/books/zhang-juzheng/download',
          language: 'zh',
          chapterCount: 4,
        ),
      );

      expect(
        requestedUri.toString(),
        'https://example.com/v1/catalog/books/zhang-juzheng/download',
      );
      expect(book.id, 'remote_zhang_juzheng');
      expect(book.title, isNotEmpty);
      expect(book.epubPath, startsWith('${tempDir.path}/books/'));
      expect(book.epubPath, endsWith('.epub'));
      expect(book.fileSize, await fixture.length());
      expect(book.importedAt, DateTime(2026, 5, 21, 12));
      expect(await File(book.epubPath).exists(), isTrue);

      final cache = await service.epubImportCacheService.read(book.id);
      expect(cache, isNotNull);
      expect(cache!.document.chapters, isNotEmpty);
    });
  });
}
