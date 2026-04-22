import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Future<String> writeBasicEpubFixture() async {
  final archive = Archive()
    ..addFile(
      ArchiveFile.noCompress(
        'mimetype',
        'application/epub+zip'.length,
        utf8.encode('application/epub+zip'),
      ),
    )
    ..addFile(
      ArchiveFile(
        'META-INF/container.xml',
        _containerXml.length,
        utf8.encode(_containerXml),
      ),
    )
    ..addFile(
      ArchiveFile('OPS/content.opf', _opfXml.length, utf8.encode(_opfXml)),
    )
    ..addFile(
      ArchiveFile('OPS/nav.xhtml', _navXhtml.length, utf8.encode(_navXhtml)),
    )
    ..addFile(
      ArchiveFile(
        'OPS/Text/chapter1.xhtml',
        _chapter1Xhtml.length,
        utf8.encode(_chapter1Xhtml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'OPS/Text/chapter2.xhtml',
        _chapter2Xhtml.length,
        utf8.encode(_chapter2Xhtml),
      ),
    )
    ..addFile(
      ArchiveFile('OPS/Images/cover.jpg', _coverBytes.length, _coverBytes),
    );

  final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
  final file = File(
    '${Directory.systemTemp.path}/fixture_${DateTime.now().microsecondsSinceEpoch}.epub',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

const _containerXml = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

const _opfXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
    <item id="chapter-1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter-1"/>
    <itemref idref="chapter-2"/>
  </spine>
</package>
''';

const _navXhtml = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <nav epub:type="toc" xmlns:epub="http://www.idpf.org/2007/ops">
      <ol>
        <li><a href="Text/chapter1.xhtml">第一章</a></li>
        <li><a href="Text/chapter2.xhtml">第二章</a></li>
      </ol>
    </nav>
  </body>
</html>
''';

const _chapter1Xhtml =
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第一章</h1><p>正文一。</p></body></html>';
const _chapter2Xhtml =
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第二章</h1><p>正文二。</p></body></html>';
final _coverBytes = List<int>.filled(16, 1, growable: false);
