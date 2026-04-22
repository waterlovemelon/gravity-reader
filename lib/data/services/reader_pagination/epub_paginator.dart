import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';

class EpubPaginator {
  final LayoutMeasurer measurer;

  const EpubPaginator({required this.measurer});

  PaginatedChapter paginate({
    required ChapterDocument chapter,
    required PaginationSettings settings,
  }) {
    final pages = <PageLayout>[];
    final currentSegments = <PageSegment>[];
    var remainingHeight = settings.contentHeight;
    var pageIndex = 0;

    for (var blockIndex = 0; blockIndex < chapter.blocks.length; blockIndex++) {
      final block = chapter.blocks[blockIndex];
      var inlineOffset = 0;

      while (true) {
        final measure = measurer.measure(
          block: block,
          settings: settings,
          remainingHeight: remainingHeight,
          startInlineOffset: inlineOffset,
        );

        if (measure.consumedHeight <= 0) {
          throw StateError(
            'Layout measurer returned non-positive height for block $blockIndex.',
          );
        }

        currentSegments.add(
          PageSegment(
            blockIndex: blockIndex,
            startInlineOffset: inlineOffset,
            endInlineOffset: measure.endInlineOffset,
            segmentType: measure.segmentType,
          ),
        );
        remainingHeight -= measure.consumedHeight;

        if (measure.fitsWholeBlock) {
          break;
        }

        pages.add(
          PageLayout(
            pageIndex: pageIndex++,
            chapterIndex: chapter.spineIndex,
            segments: List<PageSegment>.unmodifiable(currentSegments),
          ),
        );
        currentSegments.clear();
        remainingHeight = settings.contentHeight;
        inlineOffset = measure.endInlineOffset;
      }

      if (remainingHeight <= 0 && currentSegments.isNotEmpty) {
        pages.add(
          PageLayout(
            pageIndex: pageIndex++,
            chapterIndex: chapter.spineIndex,
            segments: List<PageSegment>.unmodifiable(currentSegments),
          ),
        );
        currentSegments.clear();
        remainingHeight = settings.contentHeight;
      }
    }

    if (currentSegments.isNotEmpty) {
      pages.add(
        PageLayout(
          pageIndex: pageIndex,
          chapterIndex: chapter.spineIndex,
          segments: List<PageSegment>.unmodifiable(currentSegments),
        ),
      );
    }

    return PaginatedChapter(
      chapterId: chapter.id,
      pages: List<PageLayout>.unmodifiable(pages),
    );
  }
}
