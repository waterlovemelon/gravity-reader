import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/xhtml_document_parser.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

void main() {
  test(
    'parses headings, paragraphs, emphasis, quotes, separators, and images',
    () {
      const xhtml = '''
      <html xmlns="http://www.w3.org/1999/xhtml">
        <body>
          <h1>第一章</h1>
          <p>普通 <strong>加粗</strong> 和 <em>斜体</em>。</p>
          <blockquote><p>引用内容</p></blockquote>
          <hr />
          <img src="../Images/scene.jpg" alt="scene" />
        </body>
      </html>
      ''';

      final chapter = XhtmlDocumentParser().parse(
        spineIndex: 0,
        chapterId: 'chapter-1',
        chapterHref: 'OPS/Text/chapter1.xhtml',
        fallbackTitle: '第一章',
        xhtml: xhtml,
        imageDimensions: const {
          'OPS/Images/scene.jpg': (width: 1280.0, height: 720.0),
        },
      );

      expect(chapter.title, '第一章');
      expect(chapter.blocks[0].type, BlockNodeType.heading);
      expect(
        chapter.blocks[1].children.any(
          (child) => child.type == InlineNodeType.bold,
        ),
        isTrue,
      );
      expect(
        chapter.blocks[1].children.any(
          (child) => child.type == InlineNodeType.italic,
        ),
        isTrue,
      );
      expect(chapter.blocks[2].type, BlockNodeType.quote);
      expect(chapter.blocks[3].type, BlockNodeType.separator);
      expect(chapter.blocks[4].src, 'OPS/Images/scene.jpg');
      expect(chapter.blocks[4].intrinsicWidth, 1280);
      expect(chapter.blocks[4].intrinsicHeight, 720);
    },
  );

  test('parses an image nested inside a paragraph as an image block', () {
    const xhtml = '''
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <h1>第一章</h1>
        <p class="center"><img src="../Images/scene.jpg" alt="scene" /></p>
      </body>
    </html>
    ''';

    final chapter = XhtmlDocumentParser().parse(
      spineIndex: 0,
      chapterId: 'chapter-1',
      chapterHref: 'OPS/Text/chapter1.xhtml',
      fallbackTitle: '第一章',
      xhtml: xhtml,
      imageDimensions: const {},
    );

    expect(chapter.blocks.map((block) => block.type), [
      BlockNodeType.heading,
      BlockNodeType.image,
    ]);
    expect(chapter.blocks[1].src, 'OPS/Images/scene.jpg');
  });

  test('preserves heading line breaks in chapter title', () {
    const xhtml = '''
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <h1><span>楔子</span><br />张天师祈禳瘟疫<br />洪太尉误走妖魔</h1>
        <p>正文。</p>
      </body>
    </html>
    ''';

    final chapter = XhtmlDocumentParser().parse(
      spineIndex: 0,
      chapterId: 'chapter-1',
      chapterHref: 'text/part0006.html',
      fallbackTitle: '楔子 张天师祈禳瘟疫 洪太尉误走妖魔',
      xhtml: xhtml,
      imageDimensions: const {},
    );

    expect(chapter.title, '楔子\n张天师祈禳瘟疫\n洪太尉误走妖魔');
  });

  test('parses svg cover image as an image block', () {
    const xhtml = '''
    <html xmlns="http://www.w3.org/1999/xhtml">
      <body>
        <div>
          <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
            <image width="932" height="1388" xlink:href="cover.jpeg" />
          </svg>
        </div>
      </body>
    </html>
    ''';

    final chapter = XhtmlDocumentParser().parse(
      spineIndex: 0,
      chapterId: 'titlepage',
      chapterHref: 'titlepage.xhtml',
      fallbackTitle: 'titlepage',
      xhtml: xhtml,
      imageDimensions: const {},
    );

    expect(chapter.blocks.map((block) => block.type), [BlockNodeType.image]);
    expect(chapter.blocks.single.src, 'cover.jpeg');
    expect(chapter.blocks.single.intrinsicWidth, 932);
    expect(chapter.blocks.single.intrinsicHeight, 1388);
  });
}
