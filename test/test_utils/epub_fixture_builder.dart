import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Future<String> writeBasicEpubFixture() async {
  return _writeEpubFixture(opfXml: _opfXml);
}

Future<String> writeEpubFixtureWithSpineNavPage() async {
  return _writeEpubFixture(opfXml: _opfWithSpineNavXml);
}

Future<String> writeEpubFixtureWithSpineLandmarksPage() async {
  return _writeEpubFixture(opfXml: _opfWithSpineLandmarksXml);
}

Future<String> writeEpubFixtureWithSpineContentsPage() async {
  return _writeEpubFixture(opfXml: _opfWithSpineContentsXml);
}

Future<String> writeEpub2FixtureWithNcxAndNonLinearCover() async {
  return _writeEpubFixtureWithOptions(
    opfXml: _opfWithNcxAndNonLinearCoverXml,
    ncxXml: _tocNcx,
    coverPageXhtml: _coverPageXhtml,
    catalogXhtml: _contentsXhtml,
  );
}

Future<String> _writeEpubFixture({required String opfXml}) async {
  return _writeEpubFixtureWithOptions(
    opfXml: opfXml,
    ncxXml: null,
    coverPageXhtml: null,
    catalogXhtml: null,
  );
}

Future<String> _writeEpubFixtureWithOptions({
  required String opfXml,
  required String? ncxXml,
  required String? coverPageXhtml,
  required String? catalogXhtml,
}) async {
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
      ArchiveFile('OPS/content.opf', opfXml.length, utf8.encode(opfXml)),
    )
    ..addFile(
      ArchiveFile('OPS/nav.xhtml', _navXhtml.length, utf8.encode(_navXhtml)),
    )
    ..addFile(
      ArchiveFile(
        'OPS/Text/id292.xhtml',
        _landmarksXhtml.length,
        utf8.encode(_landmarksXhtml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'OPS/Text/page0001.xhtml',
        _contentsXhtml.length,
        utf8.encode(_contentsXhtml),
      ),
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
  if (ncxXml != null) {
    archive.addFile(
      ArchiveFile('OPS/toc.ncx', ncxXml.length, utf8.encode(ncxXml)),
    );
  }
  if (coverPageXhtml != null) {
    archive.addFile(
      ArchiveFile(
        'OPS/coverpage.xhtml',
        coverPageXhtml.length,
        utf8.encode(coverPageXhtml),
      ),
    );
  }
  if (catalogXhtml != null) {
    archive.addFile(
      ArchiveFile(
        'OPS/Text/catalog.xhtml',
        catalogXhtml.length,
        utf8.encode(catalogXhtml),
      ),
    );
  }

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
    <dc:language>zh</dc:language>
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

const _opfWithSpineNavXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:language>zh</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
    <item id="chapter-1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="nav"/>
    <itemref idref="chapter-1"/>
    <itemref idref="chapter-2"/>
  </spine>
</package>
''';

const _opfWithSpineLandmarksXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:language>zh</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="id292" href="Text/id292.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
    <item id="chapter-1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="id292"/>
    <itemref idref="chapter-1"/>
    <itemref idref="chapter-2"/>
  </spine>
</package>
''';

const _opfWithSpineContentsXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:language>zh</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="page-1" href="Text/page0001.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
    <item id="chapter-1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="page-1"/>
    <itemref idref="chapter-1"/>
    <itemref idref="chapter-2"/>
  </spine>
</package>
''';

const _opfWithNcxAndNonLinearCoverXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Fixture Book</dc:title>
    <dc:creator>Fixture Author</dc:creator>
    <dc:language>zh</dc:language>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-image" href="Images/cover.jpg" media-type="image/jpeg"/>
    <item id="coverpage" href="coverpage.xhtml" media-type="application/xhtml+xml"/>
    <item id="catalog" href="Text/catalog.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter-2" href="Text/chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="toc">
    <itemref idref="coverpage" linear="no"/>
    <itemref idref="catalog"/>
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

const _tocNcx = '''
<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="navPoint-1" playOrder="1">
      <navLabel><text>封面</text></navLabel>
      <content src="coverpage.xhtml"/>
    </navPoint>
    <navPoint id="navPoint-2" playOrder="2">
      <navLabel><text>目录</text></navLabel>
      <content src="Text/catalog.xhtml"/>
    </navPoint>
    <navPoint id="navPoint-3" playOrder="3">
      <navLabel><text>第一章</text></navLabel>
      <content src="Text/chapter1.xhtml"/>
    </navPoint>
    <navPoint id="navPoint-4" playOrder="4">
      <navLabel><text>第二章</text></navLabel>
      <content src="Text/chapter2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''';

const _coverPageXhtml = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <p><img src="Images/cover.jpg" alt="cover"/></p>
  </body>
</html>
''';

const _landmarksXhtml = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>Landmarks</h1>
    <ol>
      <li><a href="../nav.xhtml">Table of Contents</a></li>
      <li><a href="../Images/cover.jpg">封面</a></li>
      <li><a href="chapter1.xhtml">Title Page</a></li>
    </ol>
  </body>
</html>
''';

const _contentsXhtml = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>目录</h1>
    <ol>
      <li><a href="chapter1.xhtml">第一章</a></li>
      <li><a href="chapter2.xhtml">第二章</a></li>
    </ol>
  </body>
</html>
''';

const _chapter1Xhtml =
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第一章</h1><p>正文一。</p></body></html>';
const _chapter2Xhtml =
    '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第二章</h1><p>正文二。</p></body></html>';
final _coverBytes = List<int>.filled(16, 1, growable: false);
