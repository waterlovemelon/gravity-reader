import 'dart:math';

import 'package:myreader/data/services/reader_pagination/epub_block_spacing.dart';
import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

class EpubPaginator {
  final LayoutMeasurer measurer;
  static const double _maxLineHeightExpansion = 0.08;
  static const double _minAdjustableLineSlots = 6;

  const EpubPaginator({required this.measurer});

  PaginatedChapter paginate({
    required ChapterDocument chapter,
    required PaginationSettings settings,
  }) {
    final pages = <PageLayout>[];
    final currentSegments = <PageSegment>[];
    var remainingHeight = 0.0;
    var pageIndex = 0;

    for (var blockIndex = 0; blockIndex < chapter.blocks.length; blockIndex++) {
      final block = chapter.blocks[blockIndex];
      var inlineOffset = 0;

      while (true) {
        if (currentSegments.isEmpty) {
          remainingHeight = _contentHeightForNewPage(
            chapter: chapter,
            settings: settings,
            firstBlockIndex: blockIndex,
            firstInlineOffset: inlineOffset,
          );
        }
        final spacingBefore = currentSegments.isEmpty
            ? 0.0
            : _spacingAfterSegment(
                chapter: chapter,
                segment: currentSegments.last,
                settings: settings,
              );
        final measurableHeight = remainingHeight - spacingBefore;
        if (measurableHeight <= 0 && currentSegments.isNotEmpty) {
          final compressedMeasure = measurer.measure(
            block: block,
            settings: settings,
            remainingHeight: remainingHeight,
            startInlineOffset: inlineOffset,
          );
          if (compressedMeasure.consumedHeight > 0) {
            final compressedSpacing =
                (remainingHeight - compressedMeasure.consumedHeight).clamp(
                  0.0,
                  spacingBefore,
                );
            final minimumSpacing = _minimumCompressedSpacing(
              spacingBefore: spacingBefore,
              segmentType: compressedMeasure.segmentType,
              fitsWholeBlock: compressedMeasure.fitsWholeBlock,
            );
            if (compressedSpacing < minimumSpacing) {
              pages.add(
                _buildPageLayout(
                  pageIndex: pageIndex++,
                  chapterIndex: chapter.spineIndex,
                  segments: currentSegments,
                  settings: settings,
                  remainingHeight: remainingHeight,
                ),
              );
              currentSegments.clear();
              remainingHeight = 0;
              continue;
            }
            _addMeasuredSegment(
              segments: currentSegments,
              blockIndex: blockIndex,
              inlineOffset: inlineOffset,
              measure: compressedMeasure,
              leadingSpacingBefore: compressedSpacing,
            );
            remainingHeight = 0;
            if (!compressedMeasure.fitsWholeBlock) {
              pages.add(
                _buildPageLayout(
                  pageIndex: pageIndex++,
                  chapterIndex: chapter.spineIndex,
                  segments: currentSegments,
                  settings: settings,
                  remainingHeight: remainingHeight,
                ),
              );
              currentSegments.clear();
              inlineOffset = compressedMeasure.endInlineOffset;
              continue;
            }
            break;
          }
          pages.add(
            _buildPageLayout(
              pageIndex: pageIndex++,
              chapterIndex: chapter.spineIndex,
              segments: currentSegments,
              settings: settings,
              remainingHeight: remainingHeight,
            ),
          );
          currentSegments.clear();
          remainingHeight = 0;
          continue;
        }

        if (_isHiddenDuplicatedTitleHeading(
          chapter: chapter,
          blockIndex: blockIndex,
          startInlineOffset: inlineOffset,
        )) {
          currentSegments.add(
            PageSegment(
              blockIndex: blockIndex,
              startInlineOffset: inlineOffset,
              endInlineOffset: _flattenInlineText(block.children).length,
              segmentType: PageSegmentType.heading,
              leadingSpacingBefore: spacingBefore,
              measuredHeight: 0,
            ),
          );
          break;
        }

        final measure = measurer.measure(
          block: block,
          settings: settings,
          remainingHeight: measurableHeight,
          startInlineOffset: inlineOffset,
        );

        if (measure.consumedHeight <= 0) {
          if (currentSegments.isNotEmpty) {
            final compressedMeasure = measurer.measure(
              block: block,
              settings: settings,
              remainingHeight: remainingHeight,
              startInlineOffset: inlineOffset,
            );
            if (compressedMeasure.consumedHeight > 0) {
              final compressedSpacing =
                  (remainingHeight - compressedMeasure.consumedHeight).clamp(
                    0.0,
                    spacingBefore,
                  );
              final minimumSpacing = _minimumCompressedSpacing(
                spacingBefore: spacingBefore,
                segmentType: compressedMeasure.segmentType,
                fitsWholeBlock: compressedMeasure.fitsWholeBlock,
              );
              if (compressedSpacing >= minimumSpacing) {
                _addMeasuredSegment(
                  segments: currentSegments,
                  blockIndex: blockIndex,
                  inlineOffset: inlineOffset,
                  measure: compressedMeasure,
                  leadingSpacingBefore: compressedSpacing,
                );
                remainingHeight = 0;
                if (!compressedMeasure.fitsWholeBlock) {
                  pages.add(
                    _buildPageLayout(
                      pageIndex: pageIndex++,
                      chapterIndex: chapter.spineIndex,
                      segments: currentSegments,
                      settings: settings,
                      remainingHeight: remainingHeight,
                    ),
                  );
                  currentSegments.clear();
                  inlineOffset = compressedMeasure.endInlineOffset;
                  continue;
                }
                break;
              }
            }
            pages.add(
              _buildPageLayout(
                pageIndex: pageIndex++,
                chapterIndex: chapter.spineIndex,
                segments: currentSegments,
                settings: settings,
                remainingHeight: remainingHeight,
              ),
            );
            currentSegments.clear();
            remainingHeight = 0;
            continue;
          }
          throw StateError(
            'Layout measurer returned non-positive height for block $blockIndex.',
          );
        }

        _addMeasuredSegment(
          segments: currentSegments,
          blockIndex: blockIndex,
          inlineOffset: inlineOffset,
          measure: measure,
          leadingSpacingBefore: spacingBefore,
        );
        remainingHeight -= spacingBefore + measure.consumedHeight;

        if (measure.fitsWholeBlock) {
          break;
        }

        pages.add(
          _buildPageLayout(
            pageIndex: pageIndex++,
            chapterIndex: chapter.spineIndex,
            segments: currentSegments,
            settings: settings,
            remainingHeight: remainingHeight,
          ),
        );
        currentSegments.clear();
        remainingHeight = 0;
        inlineOffset = measure.endInlineOffset;
      }

      if (remainingHeight <= 0 && currentSegments.isNotEmpty) {
        pages.add(
          _buildPageLayout(
            pageIndex: pageIndex++,
            chapterIndex: chapter.spineIndex,
            segments: currentSegments,
            settings: settings,
            remainingHeight: remainingHeight,
          ),
        );
        currentSegments.clear();
        remainingHeight = 0;
      }
    }

    if (currentSegments.isNotEmpty) {
      pages.add(
        _buildPageLayout(
          pageIndex: pageIndex,
          chapterIndex: chapter.spineIndex,
          segments: currentSegments,
          settings: settings,
          remainingHeight: remainingHeight,
        ),
      );
    }

    return PaginatedChapter(
      chapterId: chapter.id,
      pages: List<PageLayout>.unmodifiable(pages),
    );
  }

  PageLayout _buildPageLayout({
    required int pageIndex,
    required int chapterIndex,
    required List<PageSegment> segments,
    required PaginationSettings settings,
    required double remainingHeight,
  }) {
    final immutableSegments = List<PageSegment>.unmodifiable(segments);
    return PageLayout(
      pageIndex: pageIndex,
      chapterIndex: chapterIndex,
      segments: immutableSegments,
      lineHeightAdjustment: _lineHeightAdjustmentForPage(
        segments: immutableSegments,
        settings: settings,
        remainingHeight: remainingHeight,
      ),
    );
  }

  double _lineHeightAdjustmentForPage({
    required List<PageSegment> segments,
    required PaginationSettings settings,
    required double remainingHeight,
  }) {
    if (remainingHeight <= 0 || segments.isEmpty) {
      return 0;
    }

    final nominalLineHeightPx = settings.fontSize * settings.lineHeight;
    final maxAlignableGap = min(22.0, nominalLineHeightPx * 0.65);
    if (remainingHeight > maxAlignableGap) {
      return 0;
    }

    var lineSlots = 0.0;
    for (final segment in segments) {
      switch (segment.segmentType) {
        case PageSegmentType.paragraph:
        case PageSegmentType.quote:
          if (segment.measuredHeight <= 0) {
            return 0;
          }
          lineSlots += segment.measuredHeight / nominalLineHeightPx;
          break;
        case PageSegmentType.heading:
        case PageSegmentType.separator:
        case PageSegmentType.image:
          if (segment.measuredHeight > 0) {
            return 0;
          }
      }
    }

    if (lineSlots < _minAdjustableLineSlots) {
      return 0;
    }
    final adjustment = remainingHeight / (settings.fontSize * lineSlots);
    if (adjustment <= 0 || adjustment > _maxLineHeightExpansion) {
      return 0;
    }
    return adjustment;
  }

  double _contentHeightForNewPage({
    required ChapterDocument chapter,
    required PaginationSettings settings,
    required int firstBlockIndex,
    required int firstInlineOffset,
  }) {
    final isChapterStart = firstBlockIndex == 0 && firstInlineOffset == 0;
    if (isChapterStart && chapter.title.trim().isNotEmpty) {
      final headerHeight = max(
        settings.chapterStartPageChromeHeight,
        measurer.measureChapterHeaderHeight(
          title: chapter.title,
          settings: settings,
        ),
      );
      return max(0, settings.contentHeight - headerHeight);
    }
    return settings.contentHeightForPage(
      hasChapterTitle: chapter.title.trim().isNotEmpty,
      isChapterStart: isChapterStart,
    );
  }

  double _spacingAfterSegment({
    required ChapterDocument chapter,
    required PageSegment segment,
    required PaginationSettings settings,
  }) {
    if (_isHiddenDuplicatedTitleHeading(
      chapter: chapter,
      blockIndex: segment.blockIndex,
      startInlineOffset: segment.startInlineOffset,
    )) {
      return 0;
    }
    return epubSpacingAfter(
      chapter.blocks[segment.blockIndex],
      settings.fontSize,
    );
  }

  double _minimumCompressedSpacing({
    required double spacingBefore,
    required PageSegmentType segmentType,
    required bool fitsWholeBlock,
  }) {
    switch (segmentType) {
      case PageSegmentType.paragraph:
      case PageSegmentType.quote:
        return fitsWholeBlock ? spacingBefore.clamp(0.0, 4.0) : 0;
      case PageSegmentType.heading:
      case PageSegmentType.separator:
      case PageSegmentType.image:
        return spacingBefore.clamp(0.0, 4.0);
    }
  }

  void _addMeasuredSegment({
    required List<PageSegment> segments,
    required int blockIndex,
    required int inlineOffset,
    required BlockLayoutMeasure measure,
    required double leadingSpacingBefore,
  }) {
    segments.add(
      PageSegment(
        blockIndex: blockIndex,
        startInlineOffset: inlineOffset,
        endInlineOffset: measure.endInlineOffset,
        segmentType: measure.segmentType,
        leadingSpacingBefore: leadingSpacingBefore,
        measuredHeight: measure.consumedHeight,
      ),
    );
  }

  bool _isHiddenDuplicatedTitleHeading({
    required ChapterDocument chapter,
    required int blockIndex,
    required int startInlineOffset,
  }) {
    final chapterTitle = chapter.title.trim();
    if (chapterTitle.isEmpty || blockIndex != 0 || startInlineOffset != 0) {
      return false;
    }
    if (chapter.blocks.isEmpty) {
      return false;
    }
    final block = chapter.blocks[blockIndex];
    return block.type == BlockNodeType.heading &&
        _flattenInlineText(block.children).trim() == chapterTitle;
  }

  String _flattenInlineText(List<InlineNode> nodes) {
    return nodes.map(_flattenInlineNode).join();
  }

  String _flattenInlineNode(InlineNode node) {
    if (node.type == InlineNodeType.text) {
      return node.text;
    }
    return node.children.map(_flattenInlineNode).join();
  }
}
