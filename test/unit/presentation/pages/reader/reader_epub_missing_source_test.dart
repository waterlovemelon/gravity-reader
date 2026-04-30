import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached EPUB can open when original source file is missing', () {
    final source = File(
      'lib/presentation/pages/reader/reader_page.dart',
    ).readAsStringSync();

    expect(source, contains('resolveManagedFile('));
    expect(source, contains("managedFolderName: 'books'"));
    expect(source, contains('resolvedEpubFile.exists()'));
    expect(source, contains('_collectEpubResourceBytes('));
    expect(source, contains('<String, Uint8List>{}'));
  });
}
