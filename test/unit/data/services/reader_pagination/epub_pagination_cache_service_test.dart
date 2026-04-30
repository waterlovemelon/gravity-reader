import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/epub_pagination_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';

void main() {
  test('writes and restores chapter pagination by cache key', () async {
    final tempDir = await Directory.systemTemp.createTemp('epub_page_cache');
    final service = EpubPaginationCacheService(
      appDirProvider: () async => tempDir,
    );

    const cacheKey = EpubPaginationCacheKey(
      bookId: 'book-1',
      spineIndex: 0,
      viewportWidth: 390,
      viewportHeight: 844,
      fontSize: 20,
      lineHeight: 1.8,
      paddingPreset: 'default',
      imageLayoutPolicy: 'fit-width',
      themeProfileVersion: 1,
    );

    const page = PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 20,
          segmentType: PageSegmentType.paragraph,
        ),
      ],
    );

    await service.write(cacheKey: cacheKey, pages: const [page]);
    final restored = await service.read(cacheKey: cacheKey);

    expect(restored?.first.pageIndex, 0);
    expect(restored?.first.segments.first.endInlineOffset, 20);
  });
}
