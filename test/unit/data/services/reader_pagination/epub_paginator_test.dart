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

  test('paginator reserves rendered spacing between blocks on a page', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: const [
        BlockNode.paragraph(children: [InlineNode.text('first')]),
        BlockNode.paragraph(children: [InlineNode.text('second')]),
      ],
    );

    final result =
        EpubPaginator(
          measurer: const FixedHeightLayoutMeasurer(height: 50),
        ).paginate(
          chapter: chapter,
          settings: const PaginationSettings(
            viewportWidth: 390,
            viewportHeight: 100,
            contentPaddingTop: 0,
            contentPaddingBottom: 0,
            contentPaddingHorizontal: 24,
            fontSize: 20,
            lineHeight: 1.8,
          ),
        );

    expect(result.pages, hasLength(2));
    expect(result.pages.first.segments, hasLength(1));
    expect(result.pages.last.segments.single.blockIndex, 1);
  });

  test('paginator compresses leading spacing to keep a full line on page', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: const [
        BlockNode.paragraph(children: [InlineNode.text('first')]),
        BlockNode.paragraph(children: [InlineNode.text('second')]),
      ],
    );

    final result =
        EpubPaginator(
          measurer: const FixedHeightLayoutMeasurer(height: 35),
        ).paginate(
          chapter: chapter,
          settings: const PaginationSettings(
            viewportWidth: 390,
            viewportHeight: 75,
            contentPaddingTop: 0,
            contentPaddingBottom: 0,
            contentPaddingHorizontal: 24,
            fontSize: 20,
            lineHeight: 1.8,
          ),
        );

    expect(result.pages, hasLength(1));
    expect(result.pages.single.segments.map((segment) => segment.blockIndex), [
      0,
      1,
    ]);
    expect(result.pages.single.segments.last.leadingSpacingBefore, 5);
  });

  test(
    'paginator can remove paragraph spacing when the bottom fits one line',
    () {
      final chapter = ChapterDocument(
        spineIndex: 0,
        id: 'chapter-1',
        href: 'OPS/Text/chapter1.xhtml',
        title: '第一章',
        blocks: const [
          BlockNode.paragraph(children: [InlineNode.text('first')]),
          BlockNode.paragraph(children: [InlineNode.text('second line')]),
        ],
      );

      final result =
          EpubPaginator(
            measurer: const PartialSecondBlockLayoutMeasurer(height: 35),
          ).paginate(
            chapter: chapter,
            settings: const PaginationSettings(
              viewportWidth: 390,
              viewportHeight: 70,
              contentPaddingTop: 0,
              contentPaddingBottom: 0,
              contentPaddingHorizontal: 24,
              fontSize: 20,
              lineHeight: 1.8,
            ),
          );

      expect(result.pages, hasLength(2));
      expect(result.pages.first.segments.map((segment) => segment.blockIndex), [
        0,
        1,
      ]);
      expect(result.pages.first.segments.last.leadingSpacingBefore, 0);
      expect(result.pages.last.segments.single.blockIndex, 1);
      expect(result.pages.last.segments.single.startInlineOffset, 6);
    },
  );

  test(
    'paginator expands page line height to absorb a half-line bottom gap',
    () {
      final chapter = ChapterDocument(
        spineIndex: 0,
        id: 'chapter-1',
        href: 'OPS/Text/chapter1.xhtml',
        title: '第一章',
        blocks: const [
          BlockNode.paragraph(children: [InlineNode.text('first')]),
        ],
      );

      final result =
          EpubPaginator(
            measurer: const FixedHeightLayoutMeasurer(height: 360),
          ).paginate(
            chapter: chapter,
            settings: const PaginationSettings(
              viewportWidth: 390,
              viewportHeight: 374,
              contentPaddingTop: 0,
              contentPaddingBottom: 0,
              contentPaddingHorizontal: 24,
              fontSize: 20,
              lineHeight: 1.8,
            ),
          );

      expect(result.pages, hasLength(1));
      expect(result.pages.single.lineHeightAdjustment, closeTo(0.07, 0.001));
    },
  );

  test(
    'paginator expands split page line height to absorb a half-line bottom gap',
    () {
      final chapter = ChapterDocument(
        spineIndex: 0,
        id: 'chapter-1',
        href: 'OPS/Text/chapter1.xhtml',
        title: '第一章',
        blocks: const [
          BlockNode.paragraph(children: [InlineNode.text('first long block')]),
        ],
      );

      final result =
          EpubPaginator(
            measurer: const PartialFixedHeightLayoutMeasurer(height: 360),
          ).paginate(
            chapter: chapter,
            settings: const PaginationSettings(
              viewportWidth: 390,
              viewportHeight: 374,
              contentPaddingTop: 0,
              contentPaddingBottom: 0,
              contentPaddingHorizontal: 24,
              fontSize: 20,
              lineHeight: 1.8,
            ),
          );

      expect(result.pages.length, greaterThan(1));
      expect(result.pages.first.lineHeightAdjustment, closeTo(0.07, 0.001));
    },
  );

  test(
    'paginator uses smaller continuation chrome after chapter start page',
    () {
      final chapter = ChapterDocument(
        spineIndex: 0,
        id: 'chapter-1',
        href: 'OPS/Text/chapter1.xhtml',
        title: '第一章',
        blocks: const [
          BlockNode.paragraph(children: [InlineNode.text('first')]),
          BlockNode.paragraph(children: [InlineNode.text('second')]),
          BlockNode.paragraph(children: [InlineNode.text('third')]),
        ],
      );

      final result =
          EpubPaginator(
            measurer: const FixedHeightLayoutMeasurer(height: 50),
          ).paginate(
            chapter: chapter,
            settings: const PaginationSettings(
              viewportWidth: 390,
              viewportHeight: 150,
              contentPaddingTop: 0,
              contentPaddingBottom: 0,
              contentPaddingHorizontal: 24,
              fontSize: 20,
              lineHeight: 1.8,
              chapterStartPageChromeHeight: 80,
              continuationPageChromeHeight: 20,
            ),
          );

      expect(result.pages, hasLength(2));
      expect(result.pages.first.segments.single.blockIndex, 0);
      expect(result.pages.last.segments.map((segment) => segment.blockIndex), [
        1,
        2,
      ]);
    },
  );

  test(
    'paginator reserves measured multiline chapter title height on first page',
    () {
      final chapter = ChapterDocument(
        spineIndex: 0,
        id: 'chapter-1',
        href: 'OPS/Text/chapter1.xhtml',
        title: '第一章 很长很长的标题会换成两行',
        blocks: const [
          BlockNode.paragraph(children: [InlineNode.text('first')]),
          BlockNode.paragraph(children: [InlineNode.text('second')]),
        ],
      );

      final result =
          EpubPaginator(
            measurer: const TitleAwareFixedHeightLayoutMeasurer(
              height: 50,
              titleHeight: 80,
            ),
          ).paginate(
            chapter: chapter,
            settings: const PaginationSettings(
              viewportWidth: 390,
              viewportHeight: 160,
              contentPaddingTop: 0,
              contentPaddingBottom: 0,
              contentPaddingHorizontal: 24,
              fontSize: 20,
              lineHeight: 1.8,
              chapterStartPageChromeHeight: 40,
              continuationPageChromeHeight: 20,
            ),
          );

      expect(result.pages, hasLength(2));
      expect(result.pages.first.segments.single.blockIndex, 0);
      expect(result.pages.last.segments.single.blockIndex, 1);
    },
  );

  test('paginator does not spend body height on duplicated title heading', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: const [
        BlockNode.heading(level: 1, children: [InlineNode.text('第一章')]),
        BlockNode.paragraph(children: [InlineNode.text('正文第一段')]),
      ],
    );

    final result =
        EpubPaginator(
          measurer: const FixedHeightLayoutMeasurer(height: 50),
        ).paginate(
          chapter: chapter,
          settings: const PaginationSettings(
            viewportWidth: 390,
            viewportHeight: 150,
            contentPaddingTop: 0,
            contentPaddingBottom: 0,
            contentPaddingHorizontal: 24,
            fontSize: 20,
            lineHeight: 1.8,
            chapterStartPageChromeHeight: 80,
            continuationPageChromeHeight: 20,
          ),
        );

    expect(result.pages.first.segments.map((segment) => segment.blockIndex), [
      0,
      1,
    ]);
  });
}

class FakeLayoutMeasurer extends LayoutMeasurer {
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

class FixedHeightLayoutMeasurer extends LayoutMeasurer {
  final double height;

  const FixedHeightLayoutMeasurer({required this.height});

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    if (remainingHeight < height) {
      return const BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: 0,
        fitsWholeBlock: false,
        segmentType: PageSegmentType.paragraph,
      );
    }
    return BlockLayoutMeasure(
      consumedHeight: height,
      endInlineOffset: block.children.map((child) => child.text).join().length,
      fitsWholeBlock: true,
      segmentType: PageSegmentType.paragraph,
    );
  }
}

class TitleAwareFixedHeightLayoutMeasurer extends FixedHeightLayoutMeasurer {
  final double titleHeight;

  const TitleAwareFixedHeightLayoutMeasurer({
    required super.height,
    required this.titleHeight,
  });

  @override
  double measureChapterHeaderHeight({
    required String title,
    required PaginationSettings settings,
  }) {
    return titleHeight;
  }
}

class PartialSecondBlockLayoutMeasurer extends FixedHeightLayoutMeasurer {
  const PartialSecondBlockLayoutMeasurer({required super.height});

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    final text = block.children.map((child) => child.text).join();
    if (!text.startsWith('second')) {
      return super.measure(
        block: block,
        settings: settings,
        remainingHeight: remainingHeight,
        startInlineOffset: startInlineOffset,
      );
    }
    if (remainingHeight < height) {
      return const BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: 0,
        fitsWholeBlock: false,
        segmentType: PageSegmentType.paragraph,
      );
    }
    final endOffset = (startInlineOffset + 6).clamp(0, text.length).toInt();
    return BlockLayoutMeasure(
      consumedHeight: height,
      endInlineOffset: endOffset,
      fitsWholeBlock: endOffset >= text.length,
      segmentType: PageSegmentType.paragraph,
    );
  }
}

class PartialFixedHeightLayoutMeasurer extends FixedHeightLayoutMeasurer {
  const PartialFixedHeightLayoutMeasurer({required super.height});

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    final text = block.children.map((child) => child.text).join();
    if (remainingHeight < height) {
      return const BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: 0,
        fitsWholeBlock: false,
        segmentType: PageSegmentType.paragraph,
      );
    }
    final endOffset = (startInlineOffset + 6).clamp(0, text.length).toInt();
    return BlockLayoutMeasure(
      consumedHeight: height,
      endInlineOffset: endOffset,
      fitsWholeBlock: endOffset >= text.length,
      segmentType: PageSegmentType.paragraph,
    );
  }
}
