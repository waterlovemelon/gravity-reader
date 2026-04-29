import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myreader/data/services/reader_pagination/epub_block_spacing.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

class EpubPageContent extends StatelessWidget {
  final ChapterDocument chapter;
  final PageLayout layout;
  final EdgeInsets contentPadding;
  final TextStyle bodyTextStyle;
  final TextStyle chapterHeaderTitleStyle;
  final double chapterOverlayFontSize;
  final double chapterOverlayReservedHeight;
  final Color chapterOverlayColor;
  final StrutStyle? textStrutStyle;
  final Map<String, Uint8List> imageBytesByPath;
  final double imageMaxHeight;

  const EpubPageContent({
    super.key,
    required this.chapter,
    required this.layout,
    required this.contentPadding,
    required this.bodyTextStyle,
    required this.chapterHeaderTitleStyle,
    required this.chapterOverlayFontSize,
    required this.chapterOverlayReservedHeight,
    required this.chapterOverlayColor,
    required this.textStrutStyle,
    required this.imageBytesByPath,
    required this.imageMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final chapterLabel = chapter.title.trim();
    final showChapterHeader = _isChapterStart(layout);
    final shouldShowChapterOverlay =
        !showChapterHeader && chapterLabel.isNotEmpty;
    final blockWidgets = _buildBlockWidgets(
      context: context,
      hideLeadingTitleHeading: showChapterHeader && chapterLabel.isNotEmpty,
      chapterLabel: chapterLabel,
    );
    final titleBottomGap = ((bodyTextStyle.fontSize ?? 20) * 0.9).clamp(
      16.0,
      28.0,
    );

    return SafeArea(
      child: Padding(
        padding: contentPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shouldShowChapterOverlay)
                  SizedBox(height: chapterOverlayReservedHeight),
                if (showChapterHeader && chapterLabel.isNotEmpty) ...[
                  Text(
                    chapterLabel,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: chapterHeaderTitleStyle,
                  ),
                  SizedBox(height: titleBottomGap),
                ],
                Expanded(
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: blockWidgets,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (shouldShowChapterOverlay)
              Positioned(
                top: 0,
                left: 0,
                right: 48,
                child: IgnorePointer(
                  child: Text(
                    chapterLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: chapterOverlayFontSize,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: chapterOverlayColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBlockWidgets({
    required BuildContext context,
    required bool hideLeadingTitleHeading,
    required String chapterLabel,
  }) {
    final widgets = <Widget>[];

    for (var index = 0; index < layout.segments.length; index++) {
      final segment = layout.segments[index];
      if (segment.blockIndex < 0 ||
          segment.blockIndex >= chapter.blocks.length) {
        continue;
      }
      final block = chapter.blocks[segment.blockIndex];
      if (hideLeadingTitleHeading &&
          index == 0 &&
          block.type == BlockNodeType.heading &&
          segment.startInlineOffset == 0 &&
          _flattenInlineText(block.children).trim() == chapterLabel) {
        continue;
      }

      final widget = _buildBlockWidget(
        context: context,
        block: block,
        segment: segment,
      );
      if (widget == null) {
        continue;
      }
      widgets.add(widget);

      final spacing = _spacingAfter(block);
      if (spacing > 0) {
        widgets.add(SizedBox(height: spacing));
      }
    }

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget? _buildBlockWidget({
    required BuildContext context,
    required BlockNode block,
    required PageSegment segment,
  }) {
    switch (block.type) {
      case BlockNodeType.heading:
        final spans = _sliceTextSpans(
          nodes: block.children,
          startOffset: segment.startInlineOffset,
          endOffset: segment.endInlineOffset,
          baseStyle: _headingStyleFor(block),
        );
        if (spans.isEmpty) {
          return null;
        }
        return RichText(
          textScaler: TextScaler.noScaling,
          textAlign: TextAlign.start,
          strutStyle: _headingStrutStyle(block),
          text: TextSpan(style: _headingStyleFor(block), children: spans),
        );
      case BlockNodeType.paragraph:
        return _buildTextBlock(
          block: block,
          segment: segment,
          textAlign: TextAlign.justify,
          baseStyle: bodyTextStyle,
        );
      case BlockNodeType.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: chapterOverlayColor.withOpacity(0.4),
                width: 2,
              ),
            ),
          ),
          child: _buildTextBlock(
            block: block,
            segment: segment,
            textAlign: TextAlign.start,
            baseStyle: bodyTextStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      case BlockNodeType.separator:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            color: chapterOverlayColor.withOpacity(0.32),
            height: 1,
          ),
        );
      case BlockNodeType.image:
        return _buildImageBlock(block);
    }
  }

  Widget? _buildTextBlock({
    required BlockNode block,
    required PageSegment segment,
    required TextAlign textAlign,
    required TextStyle baseStyle,
  }) {
    final spans = _sliceTextSpans(
      nodes: block.children,
      startOffset: segment.startInlineOffset,
      endOffset: segment.endInlineOffset,
      baseStyle: baseStyle,
    );
    if (spans.isEmpty) {
      return null;
    }
    return RichText(
      textScaler: TextScaler.noScaling,
      textAlign: textAlign,
      strutStyle: textStrutStyle,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildImageBlock(BlockNode block) {
    final bytes = block.src == null ? null : imageBytesByPath[block.src!];
    final image = bytes == null
        ? _buildMissingImagePlaceholder(block.alt)
        : Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _buildMissingImagePlaceholder(block.alt),
          );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: imageMaxHeight),
        child: image,
      ),
    );
  }

  Widget _buildMissingImagePlaceholder(String? alt) {
    final label = (alt == null || alt.trim().isEmpty) ? 'Image' : alt.trim();
    return Container(
      height: min(160, imageMaxHeight),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chapterOverlayColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chapterOverlayColor.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: bodyTextStyle.copyWith(
          fontSize: max(12, (bodyTextStyle.fontSize ?? 20) * 0.72),
          color: chapterOverlayColor,
        ),
      ),
    );
  }

  TextStyle _headingStyleFor(BlockNode block) {
    final level = block.level ?? 1;
    final bodySize = bodyTextStyle.fontSize ?? 20;
    final fontSize = bodySize + max(2, 8 - level * 2);
    return bodyTextStyle.copyWith(
      fontSize: fontSize,
      height: max(1.25, (bodyTextStyle.height ?? 1.8) - 0.2),
      fontWeight: FontWeight.w700,
    );
  }

  StrutStyle _headingStrutStyle(BlockNode block) {
    final style = _headingStyleFor(block);
    return StrutStyle(
      fontSize: style.fontSize,
      height: style.height,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      leading: 0,
    );
  }

  List<InlineSpan> _sliceTextSpans({
    required List<InlineNode> nodes,
    required int startOffset,
    required int endOffset,
    required TextStyle baseStyle,
  }) {
    final runs = <_StyledTextRun>[];
    for (final node in nodes) {
      runs.addAll(_flattenNode(node, baseStyle));
    }

    if (runs.isEmpty || endOffset <= startOffset) {
      return const [];
    }

    final spans = <InlineSpan>[];
    var offset = 0;
    for (final run in runs) {
      final nextOffset = offset + run.text.length;
      final overlapStart = max(startOffset, offset);
      final overlapEnd = min(endOffset, nextOffset);
      if (overlapEnd > overlapStart) {
        final localStart = overlapStart - offset;
        final localEnd = overlapEnd - offset;
        spans.add(
          TextSpan(
            text: run.text.substring(localStart, localEnd),
            style: run.style,
          ),
        );
      }
      offset = nextOffset;
      if (offset >= endOffset) {
        break;
      }
    }
    return spans;
  }

  List<_StyledTextRun> _flattenNode(InlineNode node, TextStyle currentStyle) {
    switch (node.type) {
      case InlineNodeType.text:
        if (node.text.isEmpty) {
          return const [];
        }
        return [_StyledTextRun(text: node.text, style: currentStyle)];
      case InlineNodeType.bold:
        return _flattenChildren(
          node.children,
          currentStyle.copyWith(fontWeight: FontWeight.w700),
        );
      case InlineNodeType.italic:
        return _flattenChildren(
          node.children,
          currentStyle.copyWith(fontStyle: FontStyle.italic),
        );
      case InlineNodeType.link:
        return _flattenChildren(
          node.children,
          currentStyle.copyWith(
            color: currentStyle.color?.withOpacity(0.88),
            decoration: TextDecoration.underline,
          ),
        );
      case InlineNodeType.styledSpan:
        return _flattenChildren(
          node.children,
          _applySpanStyles(currentStyle, node.styles),
        );
    }
  }

  List<_StyledTextRun> _flattenChildren(
    List<InlineNode> children,
    TextStyle style,
  ) {
    final runs = <_StyledTextRun>[];
    for (final child in children) {
      runs.addAll(_flattenNode(child, style));
    }
    return runs;
  }

  TextStyle _applySpanStyles(TextStyle style, Map<String, String> styles) {
    var resolved = style;
    final fontWeight = styles['font-weight'];
    if (fontWeight != null) {
      final weightValue = int.tryParse(fontWeight);
      if (fontWeight.toLowerCase() == 'bold' ||
          (weightValue != null && weightValue >= 600)) {
        resolved = resolved.copyWith(fontWeight: FontWeight.w700);
      }
    }

    final fontStyle = styles['font-style'];
    if (fontStyle != null && fontStyle.toLowerCase() == 'italic') {
      resolved = resolved.copyWith(fontStyle: FontStyle.italic);
    }

    final decoration = styles['text-decoration'];
    if (decoration != null && decoration.toLowerCase().contains('underline')) {
      resolved = resolved.copyWith(decoration: TextDecoration.underline);
    }

    final color = _parseCssColor(styles['color']);
    if (color != null) {
      resolved = resolved.copyWith(color: color);
    }

    return resolved;
  }

  Color? _parseCssColor(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim().toLowerCase();
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 6) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(0xFF000000 | parsed);
        }
      }
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(parsed);
        }
      }
    }
    return null;
  }

  double _spacingAfter(BlockNode block) {
    return epubSpacingAfter(block, bodyTextStyle.fontSize ?? 20);
  }

  static bool _isChapterStart(PageLayout layout) {
    if (layout.segments.isEmpty) {
      return false;
    }
    final first = layout.segments.first;
    return first.blockIndex == 0 && first.startInlineOffset == 0;
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

class _StyledTextRun {
  final String text;
  final TextStyle style;

  const _StyledTextRun({required this.text, required this.style});
}
