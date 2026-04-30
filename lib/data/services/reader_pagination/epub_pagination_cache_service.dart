import 'dart:convert';
import 'dart:io';

import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:path_provider/path_provider.dart';

class EpubPaginationCacheKey {
  final String bookId;
  final int spineIndex;
  final double viewportWidth;
  final double viewportHeight;
  final double fontSize;
  final double lineHeight;
  final String paddingPreset;
  final String imageLayoutPolicy;
  final int themeProfileVersion;

  const EpubPaginationCacheKey({
    required this.bookId,
    required this.spineIndex,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.paddingPreset,
    required this.imageLayoutPolicy,
    required this.themeProfileVersion,
  });

  String fileName() {
    return [
      bookId,
      spineIndex,
      viewportWidth.round(),
      viewportHeight.round(),
      fontSize.toStringAsFixed(1),
      lineHeight.toStringAsFixed(2),
      paddingPreset,
      imageLayoutPolicy,
      themeProfileVersion,
    ].join('_');
  }
}

class EpubPaginationCacheService {
  final Future<Directory> Function() appDirProvider;

  const EpubPaginationCacheService({
    this.appDirProvider = getApplicationDocumentsDirectory,
  });

  Future<void> write({
    required EpubPaginationCacheKey cacheKey,
    required List<PageLayout> pages,
  }) async {
    final file = File(await _cachePath(cacheKey));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(pages.map((page) => page.toJson()).toList()),
      flush: true,
    );
  }

  Future<List<PageLayout>?> read({
    required EpubPaginationCacheKey cacheKey,
  }) async {
    final file = File(await _cachePath(cacheKey));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<dynamic>) {
      return null;
    }
    return decoded
        .cast<Map<String, dynamic>>()
        .map(PageLayout.fromJson)
        .toList(growable: false);
  }

  Future<String> _cachePath(EpubPaginationCacheKey cacheKey) async {
    final appDir = await appDirProvider();
    return '${appDir.path}/page_cache/${cacheKey.fileName()}.json';
  }
}
