import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

void main() {
  test('inspects 张居正.epub with the production EPUB import parser', () async {
    final epubFile = File('test/books/张居正.epub');
    if (!epubFile.existsSync()) {
      markTestSkipped('test/books/张居正.epub is not available locally.');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'real_epub_inspection',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = EpubImportCacheService(appDirProvider: () async => tempDir);
    final data = await service.prepare(
      bookId: 'zhang-juzheng',
      epubPath: epubFile.path,
      displayTitle: epubFile.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      ),
    );

    final emptyChapters = data.document.chapters
        .where((chapter) => _isEmptyChapter(chapter.blocks))
        .toList(growable: false);
    final imageBlocks = data.document.chapters.fold<int>(
      0,
      (sum, chapter) =>
          sum +
          chapter.blocks
              .where((block) => block.type == BlockNodeType.image)
              .length,
    );

    expect(data.document.title, '张居正');
    expect(data.document.author, '熊召政');
    expect(data.package.spineItems.length, 28);
    expect(data.package.toc.length, 28);
    expect(data.document.chapters.length, 27);
    expect(data.document.chapters.first.href, 'OPS/coverpage.html');
    expect(data.document.chapters.first.title, isEmpty);
    expect(
      data.document.chapters.first.blocks.single.type,
      BlockNodeType.image,
    );
    expect(data.document.chapters.first.blocks.single.src, 'OPS/Cover.jpg');
    expect(data.document.chapters[1].href, 'OPS/chapter1.html');
    expect(data.document.chapters[1].title, startsWith('第一回'));
    expect(data.document.chapters.last.href, 'OPS/chapter26.html');
    expect(data.document.chapters.last.title, startsWith('第二十六回'));
    expect(emptyChapters, isEmpty);
    expect(imageBlocks, 27);
  });

  test(
    'inspects 水浒传.epub with front matter kept and toc pages skipped',
    () async {
      final epubFile = File('test/books/水浒传（果麦经典）.epub');
      if (!epubFile.existsSync()) {
        markTestSkipped('test/books/水浒传（果麦经典）.epub is not available locally.');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'water_margin_epub_inspection',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = EpubImportCacheService(
        appDirProvider: () async => tempDir,
      );
      final data = await service.prepare(
        bookId: 'water-margin',
        epubPath: epubFile.path,
        displayTitle: epubFile.uri.pathSegments.last.replaceFirst(
          RegExp(r'\.[^.]+$'),
          '',
        ),
      );
      final emptyChapters = data.document.chapters
          .where((chapter) => _isEmptyChapter(chapter.blocks))
          .toList(growable: false);

      expect(data.document.title, '水浒传（果麦经典）');
      expect(data.package.toc.length, 73);
      expect(data.document.chapters.length, 78);
      expect(data.document.chapters.map((chapter) => chapter.href), [
        'titlepage.xhtml',
        'text/part0001.html',
        'text/part0002.html',
        for (var index = 3; index <= 77; index++)
          'text/part${index.toString().padLeft(4, '0')}.html',
      ]);
      expect(data.document.chapters[0].title, isEmpty);
      expect(data.document.chapters[1].title, isEmpty);
      expect(data.document.chapters[2].title, isEmpty);
      expect(
        data.document.chapters.first.blocks.single.type,
        BlockNodeType.image,
      );
      expect(data.document.chapters.first.blocks.single.src, 'cover.jpeg');
      expect(data.document.chapters[3].title, '前言');
      expect(data.document.chapters[4].title, '读第五才子书法');
      expect(data.document.chapters[6].title, '楔子\n张天师祈禳瘟疫\n洪太尉误走妖魔');
      expect(data.document.chapters[7].title, '第一回\n王教头私走延安府\n九纹龙大闹史家村');
      expect(data.document.chapters.last.href, 'text/part0077.html');
      expect(emptyChapters, isEmpty);
    },
  );
}

bool _isEmptyChapter(List<BlockNode> blocks) {
  final textLength = blocks.map(_blockText).join().trim().runes.length;
  final hasImage = blocks.any((block) => block.type == BlockNodeType.image);
  return textLength == 0 && !hasImage;
}

String _blockText(BlockNode block) {
  return block.children.map(_inlineText).join();
}

String _inlineText(InlineNode node) {
  if (node.type == InlineNodeType.text) {
    return node.text;
  }
  return node.children.map(_inlineText).join();
}
