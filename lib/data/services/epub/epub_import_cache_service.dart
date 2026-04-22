import 'dart:convert';
import 'dart:io';

import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:myreader/data/services/epub/nav_parser.dart';
import 'package:myreader/data/services/epub/opf_parser.dart';
import 'package:myreader/data/services/epub/xhtml_document_parser.dart';
import 'package:myreader/domain/entities/reader_document/book_document.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:path_provider/path_provider.dart';

class EpubImportCacheData {
  final EpubPackage package;
  final BookDocument document;
  final Map<String, ({double width, double height})> imageDimensions;

  const EpubImportCacheData({
    required this.package,
    required this.document,
    this.imageDimensions = const {},
  });

  factory EpubImportCacheData.fromJson(Map<String, dynamic> json) {
    final imageDimensionsJson =
        json['imageDimensions'] as Map<String, dynamic>? ?? const {};
    return EpubImportCacheData(
      package: EpubPackage.fromJson(json['package'] as Map<String, dynamic>),
      document: BookDocument.fromJson(json['document'] as Map<String, dynamic>),
      imageDimensions: {
        for (final entry in imageDimensionsJson.entries)
          entry.key: (
            width: ((entry.value as Map<String, dynamic>)['width'] as num)
                .toDouble(),
            height: ((entry.value as Map<String, dynamic>)['height'] as num)
                .toDouble(),
          ),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package': package.toJson(),
      'document': document.toJson(),
      'imageDimensions': {
        for (final entry in imageDimensions.entries)
          entry.key: {'width': entry.value.width, 'height': entry.value.height},
      },
    };
  }
}

class EpubImportCacheService {
  static const int cacheVersion = 1;

  final Future<Directory> Function() appDirProvider;
  final EpubArchiveService _archiveService;
  final OpfParser _opfParser;
  final NavParser _navParser;
  final XhtmlDocumentParser _xhtmlParser;

  const EpubImportCacheService({
    this.appDirProvider = getApplicationDocumentsDirectory,
    EpubArchiveService archiveService = const EpubArchiveService(),
    OpfParser opfParser = const OpfParser(),
    NavParser navParser = const NavParser(),
    XhtmlDocumentParser xhtmlParser = const XhtmlDocumentParser(),
  }) : _archiveService = archiveService,
       _opfParser = opfParser,
       _navParser = navParser,
       _xhtmlParser = xhtmlParser;

  Future<EpubImportCacheData> prepare({
    required String bookId,
    required String epubPath,
  }) async {
    final entries = await _archiveService.readEntries(epubPath);
    final packagePath = _archiveService.readContainerPath(entries);
    final parsedPackage = _opfParser.parse(
      opfXml: _archiveService.readUtf8(entries, packagePath),
      packagePath: packagePath,
    );
    final toc = _resolveToc(entries: entries, package: parsedPackage);

    final chapters = <ChapterDocument>[];
    for (final spineItem in parsedPackage.spineItems) {
      final manifestItem = parsedPackage.manifestItems[spineItem.idref];
      if (manifestItem == null || !manifestItem.mediaType.contains('xhtml')) {
        continue;
      }
      chapters.add(
        _xhtmlParser.parse(
          spineIndex: spineItem.index,
          chapterId: manifestItem.id,
          chapterHref: manifestItem.href,
          fallbackTitle: _fallbackTitleFor(
            href: manifestItem.href,
            toc: toc,
            defaultTitle: manifestItem.id,
          ),
          xhtml: _archiveService.readUtf8(entries, manifestItem.href),
          imageDimensions: const {},
        ),
      );
    }

    final package = EpubPackage(
      metadata: parsedPackage.metadata,
      manifestItems: parsedPackage.manifestItems,
      spineItems: parsedPackage.spineItems,
      toc: toc,
      packagePath: parsedPackage.packagePath,
    );

    return EpubImportCacheData(
      package: package,
      document: BookDocument(
        bookId: bookId,
        title: package.metadata.title,
        author: package.metadata.author,
        chapters: List<ChapterDocument>.unmodifiable(chapters),
      ),
    );
  }

  Future<void> write({
    required String bookId,
    required EpubImportCacheData data,
  }) async {
    final file = File(await cachePath(bookId));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }

  Future<EpubImportCacheData?> read(String bookId) async {
    final file = File(await cachePath(bookId));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return EpubImportCacheData.fromJson(decoded);
  }

  Future<String> cachePath(String bookId) async {
    final appDir = await appDirProvider();
    return '${appDir.path}/book_cache/$bookId/epub_structure_v$cacheVersion.json';
  }

  Future<String?> extractCover({
    required String epubPath,
    required EpubPackage package,
    required String destinationPath,
  }) async {
    final coverId = package.metadata.coverId;
    if (coverId == null || coverId.isEmpty) {
      return null;
    }

    final coverItem = package.manifestItems[coverId];
    if (coverItem == null) {
      return null;
    }

    final entries = await _archiveService.readEntries(epubPath);
    final bytes = entries[coverItem.href];
    if (bytes == null) {
      return null;
    }

    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  List<EpubTocEntry> _resolveToc({
    required Map<String, List<int>> entries,
    required EpubPackage package,
  }) {
    for (final item in package.manifestItems.values) {
      if (!item.properties.contains('nav')) {
        continue;
      }
      return _navParser.parseNav(
        navXml: _archiveService.readUtf8(entries, item.href),
        navPath: item.href,
      );
    }
    return const [];
  }

  String _fallbackTitleFor({
    required String href,
    required List<EpubTocEntry> toc,
    required String defaultTitle,
  }) {
    for (final entry in toc) {
      if (entry.href == href) {
        return entry.title;
      }
    }
    return defaultTitle;
  }
}
