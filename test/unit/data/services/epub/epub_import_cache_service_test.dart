import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';

import '../../../../test_utils/epub_fixture_builder.dart';

void main() {
  test('prepares, writes, and reads epub import cache data', () async {
    final epubPath = await writeBasicEpubFixture();
    final tempDir = await Directory.systemTemp.createTemp('epub_cache_test');
    final service = EpubImportCacheService(appDirProvider: () async => tempDir);

    final data = await service.prepare(bookId: 'book-1', epubPath: epubPath);

    expect(data.document.title, 'Fixture Book');
    expect(data.document.author, 'Fixture Author');
    expect(data.document.chapters.length, 2);
    expect(data.package.toc.first.title, '第一章');

    await service.write(bookId: 'book-1', data: data);
    final restored = await service.read('book-1');

    expect(restored?.document.title, 'Fixture Book');
    expect(restored?.document.chapters.length, 2);
    expect(restored?.package.toc.first.href, 'OPS/Text/chapter1.xhtml');
  });

  test(
    'extracts cover bytes into destination path when cover metadata exists',
    () async {
      final epubPath = await writeBasicEpubFixture();
      final tempDir = await Directory.systemTemp.createTemp('epub_cover_test');
      final service = EpubImportCacheService(
        appDirProvider: () async => tempDir,
      );
      final data = await service.prepare(bookId: 'book-1', epubPath: epubPath);
      final destinationPath = '${tempDir.path}/cover.jpg';

      final coverPath = await service.extractCover(
        epubPath: epubPath,
        package: data.package,
        destinationPath: destinationPath,
      );

      expect(coverPath, destinationPath);
      expect(File(destinationPath).existsSync(), isTrue);
      expect(File(destinationPath).lengthSync(), greaterThan(0));
    },
  );
}
