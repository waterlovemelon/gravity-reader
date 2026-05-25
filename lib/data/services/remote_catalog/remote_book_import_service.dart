import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:myreader/core/constants/placeholder_cover_assets.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';
import 'package:path_provider/path_provider.dart';

typedef RemoteBookDownloader = Future<List<int>> Function(Uri uri);
typedef RemoteBookIdProvider = String Function(CatalogBookSummary book);
typedef RemoteBookNowProvider = DateTime Function();
typedef PlaceholderCoverBytesProvider =
    Future<List<int>?> Function(String bookId);

class RemoteBookImportService {
  final Future<Directory> Function() appDirProvider;
  final RemoteBookDownloader _downloader;
  final RemoteBookIdProvider _idProvider;
  final RemoteBookNowProvider _nowProvider;
  final PlaceholderCoverBytesProvider _placeholderCoverBytesProvider;
  final EpubImportCacheService epubImportCacheService;
  final Uri? catalogBaseUrl;

  const RemoteBookImportService({
    this.appDirProvider = getApplicationDocumentsDirectory,
    this.catalogBaseUrl,
    RemoteBookDownloader? downloader,
    RemoteBookIdProvider? idProvider,
    RemoteBookNowProvider? nowProvider,
    PlaceholderCoverBytesProvider? placeholderCoverBytesProvider,
    this.epubImportCacheService = const EpubImportCacheService(),
  }) : _downloader = downloader ?? _downloadWithHttpClient,
       _idProvider = idProvider ?? _defaultBookId,
       _nowProvider = nowProvider ?? DateTime.now,
       _placeholderCoverBytesProvider =
           placeholderCoverBytesProvider ?? _loadPlaceholderCoverBytes;

  Future<Book> importFromCatalog(CatalogBookSummary catalogBook) async {
    final downloadUri = _resolveDownloadUri(catalogBook.downloadUrl);
    if (!downloadUri.hasScheme) {
      throw FormatException('Expected absolute download URL.', downloadUri);
    }

    final bookId = _idProvider(catalogBook);
    final appDir = await appDirProvider();
    final booksDir = Directory('${appDir.path}/books');
    final coversDir = Directory('${appDir.path}/covers');
    await booksDir.create(recursive: true);
    await coversDir.create(recursive: true);

    final epubBytes = await _downloader(downloadUri);
    final epubPath = '${booksDir.path}/${_safeFileName(bookId)}.epub';
    final epubFile = File(epubPath);
    await epubFile.writeAsBytes(epubBytes, flush: true);

    final cacheData = await epubImportCacheService.prepare(
      bookId: bookId,
      epubPath: epubFile.path,
      displayTitle: catalogBook.title,
    );
    await epubImportCacheService.write(bookId: bookId, data: cacheData);

    var coverPath = await epubImportCacheService.extractCover(
      epubPath: epubFile.path,
      package: cacheData.package,
      destinationPath: '${coversDir.path}/${_safeFileName(bookId)}.jpg',
    );
    coverPath ??= await _createPlaceholderCover(
      bookId: bookId,
      coversDir: coversDir,
    );

    return Book(
      id: bookId,
      title: cacheData.document.title,
      author: cacheData.document.author?.trim().isNotEmpty == true
          ? cacheData.document.author
          : catalogBook.author,
      coverPath: coverPath,
      epubPath: epubFile.path,
      totalPages: null,
      fileSize: epubBytes.length,
      importedAt: _nowProvider(),
    );
  }

  Future<String?> _createPlaceholderCover({
    required String bookId,
    required Directory coversDir,
  }) async {
    final bytes = await _placeholderCoverBytesProvider(bookId);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final path = '${coversDir.path}/placeholder_${_safeFileName(bookId)}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Uri _resolveDownloadUri(String downloadUrl) {
    final uri = Uri.parse(downloadUrl);
    if (uri.hasScheme) {
      return uri;
    }
    final base = catalogBaseUrl;
    if (base == null) {
      return uri;
    }
    return base.resolveUri(uri);
  }
}

Future<List<int>> _downloadWithHttpClient(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to download remote book: HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  } finally {
    client.close(force: true);
  }
}

String _defaultBookId(CatalogBookSummary book) {
  return 'remote_${_safeFileName(book.id)}';
}

String remoteCatalogLocalBookId(CatalogBookSummary book) {
  return _defaultBookId(book);
}

String _safeFileName(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : normalized;
}

Future<List<int>?> _loadPlaceholderCoverBytes(String bookId) async {
  if (placeholderCoverAssets.isEmpty) {
    return null;
  }
  final random = Random(bookId.hashCode);
  final assetPath =
      placeholderCoverAssets[random.nextInt(placeholderCoverAssets.length)];
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
