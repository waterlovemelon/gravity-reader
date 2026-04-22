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
        final containsOffset =
            locator.inlineOffset >= segment.startInlineOffset &&
            locator.inlineOffset <= segment.endInlineOffset;
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
}
