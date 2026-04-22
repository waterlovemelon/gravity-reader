import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/locator_mapper.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';

void main() {
  test('locator mapper resolves page index and page-start locator', () {
    const pages = [
      PageLayout(
        pageIndex: 0,
        chapterIndex: 0,
        segments: [
          PageSegment(
            blockIndex: 0,
            startInlineOffset: 0,
            endInlineOffset: 5,
            segmentType: PageSegmentType.heading,
          ),
        ],
      ),
      PageLayout(
        pageIndex: 1,
        chapterIndex: 0,
        segments: [
          PageSegment(
            blockIndex: 1,
            startInlineOffset: 5,
            endInlineOffset: 40,
            segmentType: PageSegmentType.paragraph,
          ),
        ],
      ),
    ];

    const locator = ReaderLocator(
      spineIndex: 0,
      blockIndex: 1,
      inlineOffset: 12,
      bias: ReaderLocatorBias.leading,
    );

    expect(LocatorMapper.pageIndexFor(locator: locator, pages: pages), 1);
    expect(LocatorMapper.locatorForPageStart(pages[1]).blockIndex, 1);
    expect(LocatorMapper.locatorForPageStart(pages[1]).inlineOffset, 5);
  });
}
