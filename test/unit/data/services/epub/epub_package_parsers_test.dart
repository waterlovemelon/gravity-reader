import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/nav_parser.dart';
import 'package:myreader/data/services/epub/opf_parser.dart';

import '../../../../test_utils/epub_fixture_builder.dart';

void main() {
  test('parses container, opf metadata, manifest, and spine', () async {
    final path = await writeBasicEpubFixture();
    final archiveService = EpubArchiveService();
    final entries = await archiveService.readEntries(path);
    final packagePath = archiveService.readContainerPath(entries);
    final package = OpfParser().parse(
      opfXml: archiveService.readUtf8(entries, packagePath),
      packagePath: packagePath,
    );

    expect(package.metadata.title, 'Fixture Book');
    expect(package.metadata.author, 'Fixture Author');
    expect(package.metadata.coverId, 'cover-image');
    expect(package.spineItems.map((item) => item.idref).toList(), [
      'chapter-1',
      'chapter-2',
    ]);
    expect(package.manifestItems['chapter-1']?.href, 'OPS/Text/chapter1.xhtml');
  });

  test('parses toc entries from nav document', () async {
    final path = await writeBasicEpubFixture();
    final archiveService = EpubArchiveService();
    final entries = await archiveService.readEntries(path);
    final toc = NavParser().parseNav(
      navXml: archiveService.readUtf8(entries, 'OPS/nav.xhtml'),
      navPath: 'OPS/nav.xhtml',
    );

    expect(toc.length, 2);
    expect(toc.first.title, '第一章');
    expect(toc.first.href, 'OPS/Text/chapter1.xhtml');
    expect(toc.last.title, '第二章');
  });
}
