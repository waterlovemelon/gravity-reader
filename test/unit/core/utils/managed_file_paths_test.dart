import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/core/utils/managed_file_paths.dart';

void main() {
  test(
    'resolves stale managed absolute path into current app directory',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'managed_file_paths_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final currentCover = File('${tempDir.path}/covers/cover.jpg');
      await currentCover.parent.create(recursive: true);
      await currentCover.writeAsBytes([1, 2, 3]);

      final resolved = await resolveManagedFile(
        '/var/mobile/Containers/Data/Application/OLD/Documents/covers/cover.jpg',
        managedFolderName: 'covers',
        appDirProvider: () async => tempDir,
      );

      expect(resolved.path, currentCover.path);
      expect(await resolved.exists(), isTrue);
    },
  );

  test('resolves relative managed path into current app directory', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'managed_file_paths_test',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final resolved = await resolveManagedFile(
      'books/imported.epub',
      managedFolderName: 'books',
      appDirProvider: () async => tempDir,
    );

    expect(resolved.path, '${tempDir.path}/books/imported.epub');
  });

  test('keeps unmanaged external path unchanged', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'managed_file_paths_test',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final resolved = await resolveManagedFile(
      '/Users/jason/Downloads/book.epub',
      managedFolderName: 'books',
      appDirProvider: () async => tempDir,
    );

    expect(resolved.path, '/Users/jason/Downloads/book.epub');
  });
}
