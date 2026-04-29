import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:myreader/presentation/pages/reader/widgets/epub_page_content.dart';

void main() {
  testWidgets('renders chapter start with title and inline emphasis', (
    tester,
  ) async {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: const [
        BlockNode.heading(level: 1, children: [InlineNode.text('第一章')]),
        BlockNode.paragraph(
          children: [
            InlineNode.text('正文'),
            InlineNode.bold(children: [InlineNode.text('强调')]),
            InlineNode.text('收尾'),
          ],
        ),
      ],
    );

    final layout = const PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 3,
          segmentType: PageSegmentType.heading,
        ),
        PageSegment(
          blockIndex: 1,
          startInlineOffset: 0,
          endInlineOffset: 6,
          segmentType: PageSegmentType.paragraph,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubPageContent(
            chapter: chapter,
            layout: layout,
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            bodyTextStyle: const TextStyle(
              fontSize: 20,
              height: 1.8,
              color: Colors.black,
            ),
            chapterHeaderTitleStyle: const TextStyle(
              fontSize: 30,
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            chapterOverlayFontSize: 13,
            chapterOverlayReservedHeight: 18,
            chapterOverlayColor: Colors.grey,
            textStrutStyle: const StrutStyle(fontSize: 20, height: 1.8),
            imageBytesByPath: const {},
            imageMaxHeight: 240,
          ),
        ),
      ),
    );

    expect(find.text('第一章'), findsOneWidget);

    final paragraph = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text)
        .whereType<TextSpan>()
        .firstWhere((span) => span.toPlainText().contains('正文强调收尾'));

    final emphasis = _findSpanByText(paragraph, '强调');
    expect(emphasis, isNotNull);
    expect(emphasis!.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('renders continued chapter overlay and images', (tester) async {
    final chapter = ChapterDocument(
      spineIndex: 1,
      id: 'chapter-2',
      href: 'OPS/Text/chapter2.xhtml',
      title: '第二章',
      blocks: const [
        BlockNode.heading(level: 1, children: [InlineNode.text('第二章')]),
        BlockNode.paragraph(children: [InlineNode.text('继续阅读')]),
        BlockNode.image(src: 'OPS/Images/scene.jpg', alt: 'scene'),
      ],
    );

    final layout = const PageLayout(
      pageIndex: 1,
      chapterIndex: 1,
      segments: [
        PageSegment(
          blockIndex: 1,
          startInlineOffset: 0,
          endInlineOffset: 4,
          segmentType: PageSegmentType.paragraph,
        ),
        PageSegment(
          blockIndex: 2,
          startInlineOffset: 0,
          endInlineOffset: 1,
          segmentType: PageSegmentType.image,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubPageContent(
            chapter: chapter,
            layout: layout,
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            bodyTextStyle: const TextStyle(
              fontSize: 20,
              height: 1.8,
              color: Colors.black,
            ),
            chapterHeaderTitleStyle: const TextStyle(
              fontSize: 30,
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            chapterOverlayFontSize: 13,
            chapterOverlayReservedHeight: 18,
            chapterOverlayColor: Colors.grey,
            textStrutStyle: const StrutStyle(fontSize: 20, height: 1.8),
            imageBytesByPath: {
              'OPS/Images/scene.jpg': Uint8List.fromList(_kTransparentImage),
            },
            imageMaxHeight: 240,
          ),
        ),
      ),
    );

    expect(find.text('第二章'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}

TextSpan? _findSpanByText(TextSpan span, String text) {
  if (span.text == text) {
    return span;
  }
  final children = span.children ?? const <InlineSpan>[];
  for (final child in children.whereType<TextSpan>()) {
    final result = _findSpanByText(child, text);
    if (result != null) {
      return result;
    }
  }
  return null;
}

const _kTransparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
