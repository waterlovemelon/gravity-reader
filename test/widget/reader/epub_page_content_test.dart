import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  testWidgets('renders image-only cover page with book title and hint', (
    tester,
  ) async {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'cover',
      href: 'titlepage.xhtml',
      title: '',
      blocks: const [BlockNode.image(src: 'cover.jpeg', alt: 'cover')],
    );

    const layout = PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 1,
          segmentType: PageSegmentType.image,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 600),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: SizedBox(
              width: 400,
              height: 600,
              child: EpubPageContent(
                chapter: chapter,
                layout: layout,
                bookTitle: '水浒传',
                bookAuthor: '施耐庵',
                contentPadding: EdgeInsets.zero,
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
                  'cover.jpeg': Uint8List.fromList(_kTransparentImage),
                },
                imageMaxHeight: 240,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('水浒传'), findsOneWidget);
    expect(find.text('施耐庵'), findsOneWidget);
    expect(find.text('左滑开始阅读'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    final pageCenterX = tester.getCenter(find.byType(EpubPageContent)).dx;
    final imageCenterX = tester.getCenter(find.byType(Image)).dx;
    expect(imageCenterX, closeTo(pageCenterX, 1));

    final groupTop = tester.getTopLeft(find.byType(Image)).dy;
    final groupBottom = tester.getBottomLeft(find.text('施耐庵')).dy;
    final groupCenterY = (groupTop + groupBottom) / 2;
    final pageCenterY = tester.getCenter(find.byType(EpubPageContent)).dy;
    expect(groupCenterY, closeTo(pageCenterY, 1));

    expect(
      tester.getTopLeft(find.text('水浒传')).dy,
      greaterThan(tester.getBottomLeft(find.byType(Image)).dy),
    );
    expect(
      tester.getTopLeft(find.text('施耐庵')).dy,
      greaterThan(tester.getBottomLeft(find.text('水浒传')).dy),
    );
    expect(
      tester.getBottomLeft(find.text('左滑开始阅读')).dy,
      closeTo(tester.getBottomLeft(find.byType(EpubPageContent)).dy - 34, 1),
    );
    final hintText = tester.widget<Text>(find.text('左滑开始阅读'));
    expect(hintText.style?.fontSize, lessThan(12));
  });

  testWidgets('renders English cover start hint for English locale', (
    tester,
  ) async {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'cover',
      href: 'titlepage.xhtml',
      title: '',
      blocks: const [BlockNode.image(src: 'cover.jpeg', alt: 'cover')],
    );

    const layout = PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 1,
          segmentType: PageSegmentType.image,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: EpubPageContent(
            chapter: chapter,
            layout: layout,
            bookTitle: 'Water Margin',
            bookAuthor: 'Shi Nai-an',
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
              'cover.jpeg': Uint8List.fromList(_kTransparentImage),
            },
            imageMaxHeight: 240,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Water Margin'), findsOneWidget);
    expect(find.text('Shi Nai-an'), findsOneWidget);
    expect(find.text('Swipe left to start reading'), findsOneWidget);
    expect(find.text('左滑开始阅读'), findsNothing);
  });

  testWidgets('uses book language for cover hint instead of app locale', (
    tester,
  ) async {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'cover',
      href: 'titlepage.xhtml',
      title: '',
      blocks: const [BlockNode.image(src: 'cover.jpeg', alt: 'cover')],
    );

    const layout = PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 1,
          segmentType: PageSegmentType.image,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: EpubPageContent(
            chapter: chapter,
            layout: layout,
            bookTitle: '水浒传',
            bookAuthor: '施耐庵',
            bookLanguage: 'zh',
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
              'cover.jpeg': Uint8List.fromList(_kTransparentImage),
            },
            imageMaxHeight: 240,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('左滑开始阅读'), findsOneWidget);
    expect(find.text('Swipe left to start reading'), findsNothing);
  });

  testWidgets('renders multiline chapter title once at chapter start', (
    tester,
  ) async {
    const title = '楔子\n张天师祈禳瘟疫\n洪太尉误走妖魔';
    final chapter = ChapterDocument(
      spineIndex: 2,
      id: 'chapter-2',
      href: 'text/part0006.html',
      title: title,
      blocks: const [
        BlockNode.heading(level: 1, children: [InlineNode.text(title)]),
        BlockNode.paragraph(children: [InlineNode.text('正文')]),
      ],
    );

    const layout = PageLayout(
      pageIndex: 0,
      chapterIndex: 2,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: title.length,
          segmentType: PageSegmentType.heading,
        ),
        PageSegment(
          blockIndex: 1,
          startInlineOffset: 0,
          endInlineOffset: 2,
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

    expect(find.text(title), findsOneWidget);
    expect(find.text('楔子 张天师祈禳瘟疫 洪太尉误走妖魔'), findsNothing);
    final richTextTitles = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((widget) => widget.text.toPlainText() == title);
    expect(richTextTitles, hasLength(1));
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
