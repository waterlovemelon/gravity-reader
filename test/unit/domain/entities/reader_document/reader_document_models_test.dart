import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';

void main() {
  test('reader document models round-trip through json', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'Text/chapter1.xhtml',
      title: '第一章',
      blocks: [
        BlockNode.heading(level: 1, children: const [InlineNode.text('第一章')]),
        BlockNode.paragraph(
          children: const [
            InlineNode.text('正文'),
            InlineNode.bold(children: [InlineNode.text('强调')]),
          ],
        ),
        const BlockNode.image(
          src: 'Images/cover.jpg',
          alt: 'cover',
          intrinsicWidth: 600,
          intrinsicHeight: 800,
        ),
      ],
    );

    final encoded = chapter.toJson();
    final decoded = ChapterDocument.fromJson(encoded);

    expect(decoded.toJson(), encoded);
  });

  test('reader locator encodes and decodes a stable string', () {
    const locator = ReaderLocator(
      spineIndex: 1,
      blockIndex: 4,
      inlineOffset: 12,
      bias: ReaderLocatorBias.trailing,
    );

    final encoded = locator.encode();
    final decoded = ReaderLocator.decode(encoded);

    expect(decoded.encode(), encoded);
  });
}
