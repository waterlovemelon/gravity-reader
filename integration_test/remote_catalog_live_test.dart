import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myreader/core/constants/app_constants.dart';
import 'package:myreader/data/services/remote_catalog/remote_book_import_service.dart';
import 'package:myreader/data/services/remote_catalog/remote_catalog_api_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fetches and imports a server catalog EPUB', (tester) async {
    final baseUrl = Uri.parse(AppConstants.catalogBaseUrl);
    final client = RemoteCatalogApiClient(baseUrl: baseUrl);

    final books = await client.fetchBooks(page: 1, pageSize: 5);
    expect(books, isNotEmpty);

    final summary = books.first;
    expect(summary.id, isNotEmpty);
    expect(summary.downloadUrl, contains('/v1/catalog/books/'));

    final detail = await client.fetchBookDetail(summary.id);
    expect(detail.id, summary.id);

    final manifest = await client.fetchManifest(summary.id);
    expect(manifest.bookId, summary.id);
    expect(manifest.chapters, isNotEmpty);

    final chapter = await client.fetchChapter(
      summary.id,
      manifest.chapters.first.id,
    );
    expect(chapter.text.trim(), isNotEmpty);

    final importer = RemoteBookImportService(catalogBaseUrl: baseUrl);
    final imported = await importer.importFromCatalog(summary.toEntity());
    final epub = File(imported.epubPath);
    expect(await epub.exists(), isTrue);
    expect(await epub.length(), greaterThan(0));

    final header = await epub.openRead(0, 2).first;
    expect(String.fromCharCodes(header), 'PK');
  });
}
