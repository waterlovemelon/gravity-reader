import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/epub_paginator.dart';
import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

void main() {
  test('paginator keeps heading on first page and splits long paragraph', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: [
        BlockNode.heading(level: 1, children: const [InlineNode.text('第一章')]),
        BlockNode.paragraph(
          children: [InlineNode.text(List.filled(200, '字').join())],
        ),
      ],
    );

    final result = EpubPaginator(measurer: const FakeLayoutMeasurer()).paginate(
      chapter: chapter,
      settings: const PaginationSettings(
        viewportWidth: 390,
        viewportHeight: 844,
        contentPaddingTop: 48,
        contentPaddingBottom: 42,
        contentPaddingHorizontal: 24,
        fontSize: 20,
        lineHeight: 1.8,
      ),
    );

    expect(result.pages.length, greaterThan(1));
    expect(result.pages.first.segments.first.blockIndex, 0);
    expect(result.pages[1].segments.first.blockIndex, 1);
    expect(result.pages[1].segments.first.startInlineOffset, greaterThan(0));
  });
}

class FakeLayoutMeasurer implements LayoutMeasurer {
  const FakeLayoutMeasurer();

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    if (block.type == BlockNodeType.heading) {
      return const BlockLayoutMeasure(
        consumedHeight: 80,
        endInlineOffset: 5,
        fitsWholeBlock: true,
        segmentType: PageSegmentType.heading,
      );
    }

    final totalLength = block.children.map((child) => child.text).join().length;
    final endOffset = (startInlineOffset + 80).clamp(0, totalLength);
    return BlockLayoutMeasure(
      consumedHeight: remainingHeight >= 220 ? 220 : remainingHeight,
      endInlineOffset: endOffset,
      fitsWholeBlock: endOffset >= totalLength,
      segmentType: PageSegmentType.paragraph,
    );
  }
}
