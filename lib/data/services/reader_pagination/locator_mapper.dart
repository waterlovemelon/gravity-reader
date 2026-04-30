import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';

class LocatorMapper {
  static int pageIndexFor({
    required ReaderLocator locator,
    required List<PageLayout> pages,
  }) {
    for (final page in pages) {
      for (final segment in page.segments) {
        final sameBlock = segment.blockIndex == locator.blockIndex;
        final containsOffset = _containsOffset(locator, segment);
        if (sameBlock && containsOffset) {
          return page.pageIndex;
        }
      }
    }
    return pages.isEmpty ? 0 : pages.last.pageIndex;
  }

  static ReaderLocator locatorForPageStart(PageLayout page) {
    final first = page.segments.first;
    return ReaderLocator(
      spineIndex: page.chapterIndex,
      blockIndex: first.blockIndex,
      inlineOffset: first.startInlineOffset,
      bias: ReaderLocatorBias.leading,
    );
  }

  static bool _containsOffset(ReaderLocator locator, PageSegment segment) {
    if (segment.startInlineOffset == segment.endInlineOffset) {
      return locator.inlineOffset == segment.startInlineOffset;
    }

    switch (locator.bias) {
      case ReaderLocatorBias.leading:
        return locator.inlineOffset >= segment.startInlineOffset &&
            locator.inlineOffset < segment.endInlineOffset;
      case ReaderLocatorBias.trailing:
        return locator.inlineOffset > segment.startInlineOffset &&
            locator.inlineOffset <= segment.endInlineOffset;
    }
  }
}
