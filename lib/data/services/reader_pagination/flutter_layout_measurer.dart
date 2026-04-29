import 'dart:math';

import 'package:flutter/material.dart';
import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

class FlutterLayoutMeasurer extends LayoutMeasurer {
  final String? fontFamily;

  const FlutterLayoutMeasurer({this.fontFamily});

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    switch (block.type) {
      case BlockNodeType.image:
        return _measureImageBlock(
          settings: settings,
          remainingHeight: remainingHeight,
        );
      case BlockNodeType.separator:
        return _measureSeparatorBlock(remainingHeight: remainingHeight);
      case BlockNodeType.heading:
      case BlockNodeType.paragraph:
      case BlockNodeType.quote:
        return _measureTextBlock(
          block: block,
          settings: settings,
          remainingHeight: remainingHeight,
          startInlineOffset: startInlineOffset,
        );
    }
  }

  BlockLayoutMeasure _measureTextBlock({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    final text = _flattenInlineText(block.children);
    if (text.isEmpty) {
      return BlockLayoutMeasure(
        consumedHeight: min(remainingHeight, 1),
        endInlineOffset: startInlineOffset,
        fitsWholeBlock: true,
        segmentType: _segmentTypeFor(block),
      );
    }

    if (startInlineOffset >= text.length) {
      return BlockLayoutMeasure(
        consumedHeight: min(remainingHeight, 1),
        endInlineOffset: text.length,
        fitsWholeBlock: true,
        segmentType: _segmentTypeFor(block),
      );
    }

    final availableWidth =
        settings.viewportWidth -
        settings.contentPaddingHorizontal * 2 -
        _horizontalInsetFor(block);
    final style = TextStyle(
      fontSize: _fontSizeFor(block, settings),
      height: _lineHeightFor(block, settings),
      fontFamily: fontFamily,
      fontWeight: block.type == BlockNodeType.heading
          ? FontWeight.w700
          : FontWeight.w400,
      fontStyle: block.type == BlockNodeType.quote
          ? FontStyle.italic
          : FontStyle.normal,
    );
    final remainingText = text.substring(startInlineOffset);
    final fullHeight = _measureTextHeight(
      text: remainingText,
      style: style,
      maxWidth: availableWidth,
    );

    if (fullHeight <= remainingHeight) {
      return BlockLayoutMeasure(
        consumedHeight: fullHeight,
        endInlineOffset: text.length,
        fitsWholeBlock: true,
        segmentType: _segmentTypeFor(block),
      );
    }

    var low = 1;
    var high = remainingText.length;
    var bestLength = 0;
    var bestHeight = 0.0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = remainingText.substring(0, mid);
      final height = _measureTextHeight(
        text: candidate,
        style: style,
        maxWidth: availableWidth,
      );
      if (height <= remainingHeight) {
        bestLength = mid;
        bestHeight = height;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (bestLength <= 0) {
      return BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: startInlineOffset,
        fitsWholeBlock: false,
        segmentType: _segmentTypeFor(block),
      );
    }

    return BlockLayoutMeasure(
      consumedHeight: bestHeight,
      endInlineOffset: startInlineOffset + bestLength,
      fitsWholeBlock: startInlineOffset + bestLength >= text.length,
      segmentType: _segmentTypeFor(block),
    );
  }

  BlockLayoutMeasure _measureImageBlock({
    required PaginationSettings settings,
    required double remainingHeight,
  }) {
    final targetHeight = min(settings.contentHeight * 0.45, remainingHeight);
    if (targetHeight < settings.contentHeight * 0.2) {
      return const BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: 0,
        fitsWholeBlock: false,
        segmentType: PageSegmentType.image,
      );
    }
    return BlockLayoutMeasure(
      consumedHeight: targetHeight,
      endInlineOffset: 1,
      fitsWholeBlock: true,
      segmentType: PageSegmentType.image,
    );
  }

  BlockLayoutMeasure _measureSeparatorBlock({required double remainingHeight}) {
    if (remainingHeight < 18) {
      return const BlockLayoutMeasure(
        consumedHeight: 0,
        endInlineOffset: 1,
        fitsWholeBlock: false,
        segmentType: PageSegmentType.separator,
      );
    }
    return const BlockLayoutMeasure(
      consumedHeight: 18,
      endInlineOffset: 1,
      fitsWholeBlock: true,
      segmentType: PageSegmentType.separator,
    );
  }

  double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: maxWidth);
    return painter.size.height;
  }

  double _fontSizeFor(BlockNode block, PaginationSettings settings) {
    if (block.type != BlockNodeType.heading) {
      return settings.fontSize;
    }
    final level = block.level ?? 1;
    return settings.fontSize + max(2, 8 - level * 2);
  }

  double _lineHeightFor(BlockNode block, PaginationSettings settings) {
    if (block.type == BlockNodeType.heading) {
      return max(1.25, settings.lineHeight - 0.2);
    }
    return settings.lineHeight;
  }

  double _horizontalInsetFor(BlockNode block) {
    if (block.type == BlockNodeType.quote) {
      return 18;
    }
    return 0;
  }

  PageSegmentType _segmentTypeFor(BlockNode block) {
    switch (block.type) {
      case BlockNodeType.heading:
        return PageSegmentType.heading;
      case BlockNodeType.paragraph:
        return PageSegmentType.paragraph;
      case BlockNodeType.quote:
        return PageSegmentType.quote;
      case BlockNodeType.separator:
        return PageSegmentType.separator;
      case BlockNodeType.image:
        return PageSegmentType.image;
    }
  }

  String _flattenInlineText(List<InlineNode> nodes) {
    return nodes.map(_flattenNode).join();
  }

  String _flattenNode(InlineNode node) {
    if (node.type == InlineNodeType.text) {
      return node.text;
    }
    return node.children.map(_flattenNode).join();
  }
}
