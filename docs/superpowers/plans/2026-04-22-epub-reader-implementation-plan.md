# EPUB Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build phase-1 EPUB reading support with real EPUB parsing, internal document modeling, one-screen-per-page pagination, structural progress restore, and integration into the existing Gravity Reader shell.

**Architecture:** Replace the current EPUB stub flow with a four-layer pipeline: EPUB package parsing, normalized document modeling, paginated layout, and reader-engine integration. Keep `ReaderPage` as the shell and move format-specific loading, pagination, and location logic into dedicated TXT and EPUB engines.

**Tech Stack:** Flutter, Dart 3, Riverpod, `archive`, `xml`, `path_provider`, `shared_preferences`, `flutter_test`, `integration_test`

---

## Planned File Structure

Create these new files:

- `lib/domain/entities/reader_document/block_node.dart` - block-level reader document nodes
- `lib/domain/entities/reader_document/inline_node.dart` - inline-level reader document nodes
- `lib/domain/entities/reader_document/chapter_document.dart` - normalized chapter container
- `lib/domain/entities/reader_document/book_document.dart` - normalized multi-chapter book container
- `lib/domain/entities/reader_document/reader_locator.dart` - structural EPUB location model
- `lib/data/services/epub/epub_package.dart` - parsed EPUB package metadata, manifest, spine, TOC
- `lib/data/services/epub/epub_archive_service.dart` - archive loading and path resolution
- `lib/data/services/epub/opf_parser.dart` - OPF parser
- `lib/data/services/epub/nav_parser.dart` - nav/NCX parser
- `lib/data/services/epub/xhtml_document_parser.dart` - XHTML to reader-document parser
- `lib/data/services/epub/epub_import_cache_service.dart` - import-time structure cache
- `lib/data/services/reader_pagination/pagination_settings.dart` - runtime pagination inputs
- `lib/data/services/reader_pagination/page_layout_model.dart` - paginated page outputs
- `lib/data/services/reader_pagination/layout_measurer.dart` - layout measurement abstraction
- `lib/data/services/reader_pagination/epub_paginator.dart` - pagination engine
- `lib/data/services/reader_pagination/locator_mapper.dart` - locator/page mapping
- `lib/data/services/reader_pagination/epub_pagination_cache_service.dart` - pagination cache persistence
- `lib/presentation/pages/reader/engines/reader_content_engine.dart` - common engine API
- `lib/presentation/pages/reader/engines/reader_engine_models.dart` - shared engine DTOs
- `lib/presentation/pages/reader/engines/txt_reader_engine.dart` - TXT adapter around existing behavior
- `lib/presentation/pages/reader/engines/epub_reader_engine.dart` - EPUB reading engine
- `lib/core/providers/reader_engine_providers.dart` - engine factory provider
- `lib/core/providers/epub_reader_providers.dart` - EPUB services/providers
- `test/test_utils/epub_fixture_builder.dart` - in-memory EPUB fixtures
- `test/unit/domain/entities/reader_document/reader_document_models_test.dart`
- `test/unit/data/services/epub/epub_package_parsers_test.dart`
- `test/unit/data/services/epub/xhtml_document_parser_test.dart`
- `test/unit/data/services/epub/epub_import_cache_service_test.dart`
- `test/unit/data/services/reader_pagination/epub_paginator_test.dart`
- `test/unit/data/services/reader_pagination/locator_mapper_test.dart`
- `test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart`
- `test/unit/presentation/pages/reader/engines/txt_reader_engine_test.dart`
- `test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart`
- `test/widget/reader/reader_page_epub_test.dart`
- `integration_test/epub_reader_smoke_test.dart`

Modify these existing files:

- `pubspec.yaml` - add EPUB parsing dependencies
- `lib/flureadium_integration/epub_parser.dart` - convert stub parser into transitional adapter
- `lib/flureadium_integration/epub_providers.dart` - delegate to real EPUB services
- `lib/presentation/pages/bookshelf/bookshelf_page.dart` - use EPUB structure cache during import
- `lib/presentation/pages/reader/reader_page.dart` - delegate loading/page content/TOC/progress to reader engines
- `test/widget_test.dart` - keep app boot test green after provider additions

## Task 1: Add Reader Document Foundation

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/domain/entities/reader_document/block_node.dart`
- Create: `lib/domain/entities/reader_document/inline_node.dart`
- Create: `lib/domain/entities/reader_document/chapter_document.dart`
- Create: `lib/domain/entities/reader_document/book_document.dart`
- Create: `lib/domain/entities/reader_document/reader_locator.dart`
- Test: `test/unit/domain/entities/reader_document/reader_document_models_test.dart`

- [ ] **Step 1: Write the failing model tests**

```dart
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
        BlockNode.heading(
          level: 1,
          children: const [InlineNode.text('第一章')],
        ),
        BlockNode.paragraph(
          children: const [
            InlineNode.text('正文'),
            InlineNode.bold(children: [InlineNode.text('强调')]),
          ],
        ),
        BlockNode.image(
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
flutter test test/unit/domain/entities/reader_document/reader_document_models_test.dart -r expanded
```

Expected: FAIL with missing imports under `lib/domain/entities/reader_document/`.

- [ ] **Step 3: Write the minimal document model implementation**

```dart
// lib/domain/entities/reader_document/inline_node.dart
enum InlineNodeType { text, bold, italic, link, styledSpan }

class InlineNode {
  final InlineNodeType type;
  final String text;
  final String? href;
  final Map<String, String> styles;
  final List<InlineNode> children;

  const InlineNode({
    required this.type,
    this.text = '',
    this.href,
    this.styles = const {},
    this.children = const [],
  });

  const InlineNode.text(String value)
      : type = InlineNodeType.text,
        text = value,
        href = null,
        styles = const {},
        children = const [];

  const InlineNode.bold({required List<InlineNode> children})
      : type = InlineNodeType.bold,
        text = '',
        href = null,
        styles = const {},
        children = children;

  const InlineNode.italic({required List<InlineNode> children})
      : type = InlineNodeType.italic,
        text = '',
        href = null,
        styles = const {},
        children = children;

  const InlineNode.link({
    required String href,
    required List<InlineNode> children,
  })  : type = InlineNodeType.link,
        text = '',
        href = href,
        styles = const {},
        children = children;

  const InlineNode.styledSpan({
    required Map<String, String> styles,
    required List<InlineNode> children,
  })  : type = InlineNodeType.styledSpan,
        text = '',
        href = null,
        styles = styles,
        children = children;

  factory InlineNode.fromJson(Map<String, dynamic> json) {
    return InlineNode(
      type: InlineNodeType.values.byName(json['type'] as String),
      text: json['text'] as String? ?? '',
      href: json['href'] as String?,
      styles: Map<String, String>.from(
        json['styles'] as Map<String, dynamic>? ?? const {},
      ),
      children: (json['children'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(InlineNode.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'href': href,
      'styles': styles,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}
```

```dart
// lib/domain/entities/reader_document/block_node.dart
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

enum BlockNodeType { heading, paragraph, quote, separator, image }

class BlockNode {
  final BlockNodeType type;
  final int? level;
  final List<InlineNode> children;
  final String? src;
  final String? alt;
  final double? intrinsicWidth;
  final double? intrinsicHeight;
  final Map<String, String> styles;

  const BlockNode({
    required this.type,
    this.level,
    this.children = const [],
    this.src,
    this.alt,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.styles = const {},
  });

  const BlockNode.heading({
    required int level,
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(
          type: BlockNodeType.heading,
          level: level,
          children: children,
          styles: styles,
        );

  const BlockNode.paragraph({
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(
          type: BlockNodeType.paragraph,
          children: children,
          styles: styles,
        );

  const BlockNode.quote({
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(
          type: BlockNodeType.quote,
          children: children,
          styles: styles,
        );

  const BlockNode.separator()
      : this(type: BlockNodeType.separator, children: const []);

  const BlockNode.image({
    required String src,
    String? alt,
    double? intrinsicWidth,
    double? intrinsicHeight,
  }) : this(
          type: BlockNodeType.image,
          src: src,
          alt: alt,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
          children: const [],
        );

  factory BlockNode.fromJson(Map<String, dynamic> json) {
    return BlockNode(
      type: BlockNodeType.values.byName(json['type'] as String),
      level: json['level'] as int?,
      children: (json['children'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(InlineNode.fromJson)
          .toList(growable: false),
      src: json['src'] as String?,
      alt: json['alt'] as String?,
      intrinsicWidth: (json['intrinsicWidth'] as num?)?.toDouble(),
      intrinsicHeight: (json['intrinsicHeight'] as num?)?.toDouble(),
      styles: Map<String, String>.from(
        json['styles'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'level': level,
      'children': children.map((child) => child.toJson()).toList(),
      'src': src,
      'alt': alt,
      'intrinsicWidth': intrinsicWidth,
      'intrinsicHeight': intrinsicHeight,
      'styles': styles,
    };
  }
}
```

```dart
// lib/domain/entities/reader_document/chapter_document.dart
import 'package:myreader/domain/entities/reader_document/block_node.dart';

class ChapterDocument {
  final int spineIndex;
  final String id;
  final String href;
  final String title;
  final List<BlockNode> blocks;

  const ChapterDocument({
    required this.spineIndex,
    required this.id,
    required this.href,
    required this.title,
    required this.blocks,
  });

  factory ChapterDocument.fromJson(Map<String, dynamic> json) {
    return ChapterDocument(
      spineIndex: json['spineIndex'] as int,
      id: json['id'] as String,
      href: json['href'] as String,
      title: json['title'] as String? ?? '',
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BlockNode.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spineIndex': spineIndex,
      'id': id,
      'href': href,
      'title': title,
      'blocks': blocks.map((block) => block.toJson()).toList(),
    };
  }
}
```

```dart
// lib/domain/entities/reader_document/book_document.dart
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';

class BookDocument {
  final String bookId;
  final String title;
  final String? author;
  final List<ChapterDocument> chapters;

  const BookDocument({
    required this.bookId,
    required this.title,
    this.author,
    required this.chapters,
  });

  factory BookDocument.fromJson(Map<String, dynamic> json) {
    return BookDocument(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      chapters: (json['chapters'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ChapterDocument.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'author': author,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }
}
```

```dart
// lib/domain/entities/reader_document/reader_locator.dart
import 'dart:convert';

enum ReaderLocatorBias { leading, trailing }

class ReaderLocator {
  final int spineIndex;
  final int blockIndex;
  final int inlineOffset;
  final ReaderLocatorBias bias;

  const ReaderLocator({
    required this.spineIndex,
    required this.blockIndex,
    required this.inlineOffset,
    required this.bias,
  });

  Map<String, dynamic> toJson() {
    return {
      'spineIndex': spineIndex,
      'blockIndex': blockIndex,
      'inlineOffset': inlineOffset,
      'bias': bias.name,
    };
  }

  String encode() => jsonEncode(toJson());

  factory ReaderLocator.fromJson(Map<String, dynamic> json) {
    return ReaderLocator(
      spineIndex: json['spineIndex'] as int,
      blockIndex: json['blockIndex'] as int,
      inlineOffset: json['inlineOffset'] as int,
      bias: ReaderLocatorBias.values.byName(json['bias'] as String),
    );
  }

  factory ReaderLocator.decode(String value) {
    return ReaderLocator.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Run the model tests and format the new files**

Run:

```bash
dart format lib/domain/entities/reader_document test/unit/domain/entities/reader_document
flutter test test/unit/domain/entities/reader_document/reader_document_models_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the model foundation**

```bash
git add pubspec.yaml lib/domain/entities/reader_document test/unit/domain/entities/reader_document
git commit -m "feat: add reader document foundation"
```

## Task 2: Implement EPUB Package Parsing

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/services/epub/epub_package.dart`
- Create: `lib/data/services/epub/epub_archive_service.dart`
- Create: `lib/data/services/epub/opf_parser.dart`
- Create: `lib/data/services/epub/nav_parser.dart`
- Create: `test/test_utils/epub_fixture_builder.dart`
- Test: `test/unit/data/services/epub/epub_package_parsers_test.dart`

- [ ] **Step 1: Write the failing parser tests and fixture builder scaffold**

```yaml
# pubspec.yaml
dependencies:
  archive: ^3.6.1
  xml: ^6.5.0
```

```dart
// test/test_utils/epub_fixture_builder.dart
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

const _chapter1Xhtml = '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第一章</h1><p>正文一。</p></body></html>';
const _chapter2Xhtml = '<html xmlns="http://www.w3.org/1999/xhtml"><body><h1>第二章</h1><p>正文二。</p></body></html>';
final _coverBytes = List<int>.filled(16, 1, growable: false);
```

```dart
// test/unit/data/services/epub/epub_package_parsers_test.dart
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
    expect(package.spineItems.map((item) => item.idref).toList(), [
      'chapter-1',
      'chapter-2',
    ]);
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
  });
}
```

- [ ] **Step 2: Run dependency install and verify the tests fail**

Run:

```bash
flutter pub get
flutter test test/unit/data/services/epub/epub_package_parsers_test.dart -r expanded
```

Expected: FAIL with missing parser/service implementations.

- [ ] **Step 3: Implement the archive and package parsers**

```dart
// lib/data/services/epub/epub_package.dart
class EpubMetadata {
  final String title;
  final String? author;
  final String? coverId;

  const EpubMetadata({
    required this.title,
    this.author,
    this.coverId,
  });
}

class EpubManifestItem {
  final String id;
  final String href;
  final String mediaType;
  final Set<String> properties;

  const EpubManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties = const {},
  });
}

class EpubSpineItem {
  final String idref;
  final int index;

  const EpubSpineItem({required this.idref, required this.index});
}

class EpubTocEntry {
  final String title;
  final String href;

  const EpubTocEntry({required this.title, required this.href});
}

class EpubPackage {
  final EpubMetadata metadata;
  final Map<String, EpubManifestItem> manifestItems;
  final List<EpubSpineItem> spineItems;
  final List<EpubTocEntry> toc;
  final String packagePath;

  const EpubPackage({
    required this.metadata,
    required this.manifestItems,
    required this.spineItems,
    required this.toc,
    required this.packagePath,
  });
}
```

```dart
// lib/data/services/epub/epub_archive_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class EpubArchiveService {
  Future<Map<String, List<int>>> readEntries(String epubPath) async {
    final bytes = await File(epubPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return {
      for (final file in archive.files)
        if (!file.isFile) file.name: const [],
        if (file.isFile) file.name: (file.content as List<int>),
    };
  }

  String readUtf8(Map<String, List<int>> entries, String path) {
    final data = entries[path];
    if (data == null) {
      throw StateError('Missing archive entry: $path');
    }
    return utf8.decode(data);
  }

  String readContainerPath(Map<String, List<int>> entries) {
    final document = XmlDocument.parse(
      readUtf8(entries, 'META-INF/container.xml'),
    );
    final rootfile = document.findAllElements('rootfile').first;
    return rootfile.getAttribute('full-path')!;
  }

  String resolvePath({
    required String basePath,
    required String relativePath,
  }) {
    final baseSegments = basePath.split('/')..removeLast();
    for (final segment in relativePath.split('/')) {
      if (segment == '.' || segment.isEmpty) {
        continue;
      }
      if (segment == '..' && baseSegments.isNotEmpty) {
        baseSegments.removeLast();
        continue;
      }
      baseSegments.add(segment);
    }
    return baseSegments.join('/');
  }
}
```

```dart
// lib/data/services/epub/opf_parser.dart
import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:xml/xml.dart';

class OpfParser {
  EpubPackage parse({
    required String opfXml,
    required String packagePath,
  }) {
    final document = XmlDocument.parse(opfXml);
    final metadataNode = document.findAllElements('metadata').first;
    final manifestNode = document.findAllElements('manifest').first;
    final spineNode = document.findAllElements('spine').first;

    final title = metadataNode
            .findElements('dc:title')
            .map((node) => node.innerText.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => 'Untitled') ??
        'Untitled';
    final author = metadataNode
        .findElements('dc:creator')
        .map((node) => node.innerText.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final coverMeta = metadataNode
        .findElements('meta')
        .where((node) => node.getAttribute('name') == 'cover')
        .map((node) => node.getAttribute('content'))
        .whereType<String>()
        .cast<String?>()
        .firstWhere((value) => value != null, orElse: () => null);

    final manifest = {
      for (final item in manifestNode.findElements('item'))
        item.getAttribute('id')!: EpubManifestItem(
          id: item.getAttribute('id')!,
          href: EpubArchiveService().resolvePath(
            basePath: packagePath,
            relativePath: item.getAttribute('href')!,
          ),
          mediaType: item.getAttribute('media-type')!,
          properties: (item.getAttribute('properties') ?? '')
              .split(' ')
              .where((part) => part.isNotEmpty)
              .toSet(),
        ),
    };

    final spine = spineNode
        .findElements('itemref')
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => EpubSpineItem(
            idref: entry.value.getAttribute('idref')!,
            index: entry.key,
          ),
        )
        .toList(growable: false);

    return EpubPackage(
      metadata: EpubMetadata(
        title: title,
        author: author.isEmpty ? null : author,
        coverId: coverMeta,
      ),
      manifestItems: manifest,
      spineItems: spine,
      toc: const [],
      packagePath: packagePath,
    );
  }
}
```

```dart
// lib/data/services/epub/nav_parser.dart
import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:xml/xml.dart';

class NavParser {
  List<EpubTocEntry> parseNav({
    required String navXml,
    required String navPath,
  }) {
    final document = XmlDocument.parse(navXml);
    return document
        .findAllElements('a')
        .map(
          (anchor) => EpubTocEntry(
            title: anchor.innerText.trim(),
            href: EpubArchiveService().resolvePath(
              basePath: navPath,
              relativePath: anchor.getAttribute('href')!,
            ),
          ),
        )
        .where((entry) => entry.title.isNotEmpty)
        .toList(growable: false);
  }
}
```

- [ ] **Step 4: Run parser tests and format the new EPUB services**

Run:

```bash
dart format lib/data/services/epub test/test_utils test/unit/data/services/epub
flutter test test/unit/data/services/epub/epub_package_parsers_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the package parser layer**

```bash
git add pubspec.yaml pubspec.lock lib/data/services/epub test/test_utils/epub_fixture_builder.dart test/unit/data/services/epub
git commit -m "feat: add epub package parsers"
```

## Task 3: Convert XHTML Into Reader Documents

**Files:**
- Create: `lib/data/services/epub/xhtml_document_parser.dart`
- Test: `test/unit/data/services/epub/xhtml_document_parser_test.dart`

- [ ] **Step 1: Write the failing XHTML parser tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/xhtml_document_parser.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';

void main() {
  test('parses headings, paragraphs, emphasis, quotes, separators, and images', () {
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
      imageDimensions: const {'OPS/Images/scene.jpg': (1280.0, 720.0)},
    );

    expect(chapter.blocks.first.type, BlockNodeType.heading);
    expect(chapter.blocks[1].children[1].type, InlineNodeType.bold);
    expect(chapter.blocks[1].children[2].type, InlineNodeType.text);
    expect(chapter.blocks[2].type, BlockNodeType.quote);
    expect(chapter.blocks[3].type, BlockNodeType.separator);
    expect(chapter.blocks[4].src, 'OPS/Images/scene.jpg');
  });
}
```

- [ ] **Step 2: Run the XHTML parser test to confirm the failure**

Run:

```bash
flutter test test/unit/data/services/epub/xhtml_document_parser_test.dart -r expanded
```

Expected: FAIL with missing `XhtmlDocumentParser`.

- [ ] **Step 3: Implement the XHTML parser**

```dart
// lib/data/services/epub/xhtml_document_parser.dart
import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:xml/xml.dart';

typedef ImageDimensionLookup = Map<String, (double, double)>;

class XhtmlDocumentParser {
  ChapterDocument parse({
    required int spineIndex,
    required String chapterId,
    required String chapterHref,
    required String fallbackTitle,
    required String xhtml,
    required ImageDimensionLookup imageDimensions,
  }) {
    final document = XmlDocument.parse(xhtml);
    final body = document.findAllElements('body').first;
    final blocks = <BlockNode>[];

    for (final node in body.children.whereType<XmlNode>()) {
      blocks.addAll(
        _parseBlockNode(
          node: node,
          chapterHref: chapterHref,
          imageDimensions: imageDimensions,
        ),
      );
    }

    final resolvedTitle = blocks
        .where((block) => block.type == BlockNodeType.heading)
        .map((block) => block.children.map((child) => child.text).join())
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => fallbackTitle);

    return ChapterDocument(
      spineIndex: spineIndex,
      id: chapterId,
      href: chapterHref,
      title: resolvedTitle,
      blocks: blocks,
    );
  }

  List<BlockNode> _parseBlockNode({
    required XmlNode node,
    required String chapterHref,
    required ImageDimensionLookup imageDimensions,
  }) {
    if (node is XmlText) {
      final text = node.value.trim();
      if (text.isEmpty) {
        return const [];
      }
      return [
        BlockNode.paragraph(children: [InlineNode.text(text)]),
      ];
    }

    if (node is! XmlElement) {
      return const [];
    }

    switch (node.name.local) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return [
          BlockNode.heading(
            level: int.parse(node.name.local.substring(1)),
            children: _parseInlineNodes(node),
          ),
        ];
      case 'p':
        return [
          BlockNode.paragraph(children: _parseInlineNodes(node)),
        ];
      case 'blockquote':
        return [
          BlockNode.quote(children: _parseInlineNodes(node)),
        ];
      case 'hr':
        return const [BlockNode.separator()];
      case 'img':
        final resolvedSrc = EpubArchiveService().resolvePath(
          basePath: chapterHref,
          relativePath: node.getAttribute('src')!,
        );
        final dims = imageDimensions[resolvedSrc];
        return [
          BlockNode.image(
            src: resolvedSrc,
            alt: node.getAttribute('alt'),
            intrinsicWidth: dims?.$1,
            intrinsicHeight: dims?.$2,
          ),
        ];
      case 'section':
      case 'div':
      case 'article':
      case 'body':
        return node.children
            .expand(
              (child) => _parseBlockNode(
                node: child,
                chapterHref: chapterHref,
                imageDimensions: imageDimensions,
              ),
            )
            .toList(growable: false);
      default:
        final inlineChildren = _parseInlineNodes(node);
        if (inlineChildren.isEmpty) {
          return const [];
        }
        return [
          BlockNode.paragraph(children: inlineChildren),
        ];
    }
  }

  List<InlineNode> _parseInlineNodes(XmlNode node) {
    return node.children.expand((child) {
      if (child is XmlText) {
        final value = child.value.replaceAll(RegExp(r'\s+'), ' ').trim();
        return value.isEmpty ? const <InlineNode>[] : <InlineNode>[InlineNode.text(value)];
      }
      if (child is! XmlElement) {
        return const <InlineNode>[];
      }

      final nested = _parseInlineNodes(child);
      switch (child.name.local) {
        case 'strong':
        case 'b':
          return <InlineNode>[InlineNode.bold(children: nested)];
        case 'em':
        case 'i':
          return <InlineNode>[InlineNode.italic(children: nested)];
        case 'a':
          return <InlineNode>[
            InlineNode.link(
              href: child.getAttribute('href') ?? '',
              children: nested,
            ),
          ];
        case 'span':
          return <InlineNode>[
            InlineNode.styledSpan(
              styles: _parseStyleMap(child.getAttribute('style')),
              children: nested,
            ),
          ];
        default:
          return nested;
      }
    }).toList(growable: false);
  }

  Map<String, String> _parseStyleMap(String? style) {
    if (style == null || style.trim().isEmpty) {
      return const {};
    }
    return {
      for (final part in style.split(';'))
        if (part.contains(':'))
          part.split(':').first.trim(): part.split(':').last.trim(),
    };
  }
}
```

- [ ] **Step 4: Run the XHTML parser tests and format the file**

Run:

```bash
dart format lib/data/services/epub/xhtml_document_parser.dart test/unit/data/services/epub/xhtml_document_parser_test.dart
flutter test test/unit/data/services/epub/xhtml_document_parser_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the XHTML document parser**

```bash
git add lib/data/services/epub/xhtml_document_parser.dart test/unit/data/services/epub/xhtml_document_parser_test.dart
git commit -m "feat: add xhtml document parser"
```

## Task 4: Persist EPUB Structure Cache and Wire Import Flow

**Files:**
- Create: `lib/data/services/epub/epub_import_cache_service.dart`
- Modify: `lib/presentation/pages/bookshelf/bookshelf_page.dart`
- Test: `test/unit/data/services/epub/epub_import_cache_service_test.dart`

- [ ] **Step 1: Write the failing import cache test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:myreader/domain/entities/reader_document/book_document.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';

void main() {
  test('writes and reads epub import cache data', () async {
    final tempDir = await Directory.systemTemp.createTemp('epub_cache_test');
    final service = EpubImportCacheService(
      appDirProvider: () async => tempDir,
    );

    final data = EpubImportCacheData(
      package: EpubPackage(
        metadata: const EpubMetadata(title: 'Fixture Book', author: 'Fixture Author'),
        manifestItems: const {},
        spineItems: const [],
        toc: const [EpubTocEntry(title: '第一章', href: 'OPS/Text/chapter1.xhtml')],
        packagePath: 'OPS/content.opf',
      ),
      document: const BookDocument(
        bookId: 'book-1',
        title: 'Fixture Book',
        author: 'Fixture Author',
        chapters: [
          ChapterDocument(
            spineIndex: 0,
            id: 'chapter-1',
            href: 'OPS/Text/chapter1.xhtml',
            title: '第一章',
            blocks: [],
          ),
        ],
      ),
      imageDimensions: const {'OPS/Images/cover.jpg': (600.0, 800.0)},
    );

    await service.write(bookId: 'book-1', data: data);
    final restored = await service.read('book-1');

    expect(restored?.document.title, 'Fixture Book');
    expect(restored?.document.chapters.length, 1);
    expect(restored?.package.toc.first.title, '第一章');
  });
}
```

- [ ] **Step 2: Run the import cache test and confirm the failure**

Run:

```bash
flutter test test/unit/data/services/epub/epub_import_cache_service_test.dart -r expanded
```

Expected: FAIL with missing `EpubImportCacheService`.

- [ ] **Step 3: Implement structural caching and use it during EPUB import**

```dart
// lib/data/services/epub/epub_import_cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:myreader/domain/entities/reader_document/book_document.dart';
import 'package:path_provider/path_provider.dart';

class EpubImportCacheData {
  final EpubPackage package;
  final BookDocument document;
  final Map<String, (double, double)> imageDimensions;

  const EpubImportCacheData({
    required this.package,
    required this.document,
    required this.imageDimensions,
  });

  Map<String, dynamic> toJson() {
    return {
      'packagePath': package.packagePath,
      'metadata': {
        'title': package.metadata.title,
        'author': package.metadata.author,
        'coverId': package.metadata.coverId,
      },
      'toc': package.toc
          .map((entry) => {'title': entry.title, 'href': entry.href})
          .toList(),
      'document': document.toJson(),
      'imageDimensions': {
        for (final entry in imageDimensions.entries)
          entry.key: [entry.value.$1, entry.value.$2],
      },
    };
  }

  factory EpubImportCacheData.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    return EpubImportCacheData(
      package: EpubPackage(
        metadata: EpubMetadata(
          title: metadata['title'] as String,
          author: metadata['author'] as String?,
          coverId: metadata['coverId'] as String?,
        ),
        manifestItems: const {},
        spineItems: const [],
        toc: (json['toc'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              (entry) => EpubTocEntry(
                title: entry['title'] as String,
                href: entry['href'] as String,
              ),
            )
            .toList(growable: false),
        packagePath: json['packagePath'] as String,
      ),
      document: BookDocument.fromJson(json['document'] as Map<String, dynamic>),
      imageDimensions: {
        for (final entry in (json['imageDimensions'] as Map<String, dynamic>).entries)
          entry.key: (
            (entry.value as List<dynamic>)[0] as double,
            (entry.value as List<dynamic>)[1] as double,
          ),
      },
    );
  }
}

class EpubImportCacheService {
  static const cacheVersion = 1;
  final Future<Directory> Function() appDirProvider;

  const EpubImportCacheService({
    this.appDirProvider = getApplicationDocumentsDirectory,
  });

  Future<String> cachePath(String bookId) async {
    final appDir = await appDirProvider();
    return '${appDir.path}/book_cache/$bookId/epub_structure_v$cacheVersion.json';
  }

  Future<void> write({
    required String bookId,
    required EpubImportCacheData data,
  }) async {
    final file = File(await cachePath(bookId));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }

  Future<EpubImportCacheData?> read(String bookId) async {
    final file = File(await cachePath(bookId));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return EpubImportCacheData.fromJson(decoded);
  }
}
```

```dart
// lib/presentation/pages/bookshelf/bookshelf_page.dart
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';

final EpubImportCacheService _epubImportCacheService =
    const EpubImportCacheService();
```

```dart
// lib/presentation/pages/bookshelf/bookshelf_page.dart
if (fileExt == 'epub') {
  final appDir = await getApplicationDocumentsDirectory();
  final coversDir = Directory('${appDir.path}/covers');
  if (!await coversDir.exists()) {
    await coversDir.create(recursive: true);
  }

  final parser = EpubParserImpl();
  final cacheData = await _epubImportCacheService.prepare(
    bookId: bookId,
    epubPath: newPath,
  );
  await _epubImportCacheService.write(bookId: bookId, data: cacheData);

  title = cacheData.document.title;
  author = cacheData.document.author;
  totalPages = null;
  coverPath = await parser.extractCover(
    newPath,
    '${coversDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
}
```

```dart
// lib/data/services/epub/epub_import_cache_service.dart
Future<EpubImportCacheData> prepare({
  required String bookId,
  required String epubPath,
}) async {
  final entries = await EpubArchiveService().readEntries(epubPath);
  final packagePath = EpubArchiveService().readContainerPath(entries);
  final package = OpfParser().parse(
    opfXml: EpubArchiveService().readUtf8(entries, packagePath),
    packagePath: packagePath,
  );
  final navItem = package.manifestItems.values.firstWhere(
    (item) => item.properties.contains('nav'),
  );
  final toc = NavParser().parseNav(
    navXml: EpubArchiveService().readUtf8(entries, navItem.href),
    navPath: navItem.href,
  );
  final chapters = <ChapterDocument>[];
  for (final spineItem in package.spineItems) {
    final manifestItem = package.manifestItems[spineItem.idref]!;
    chapters.add(
      XhtmlDocumentParser().parse(
        spineIndex: spineItem.index,
        chapterId: manifestItem.id,
        chapterHref: manifestItem.href,
        fallbackTitle: toc
            .where((entry) => entry.href == manifestItem.href)
            .map((entry) => entry.title)
            .firstWhere((value) => value.isNotEmpty, orElse: () => manifestItem.id),
        xhtml: EpubArchiveService().readUtf8(entries, manifestItem.href),
        imageDimensions: const {},
      ),
    );
  }

  return EpubImportCacheData(
    package: EpubPackage(
      metadata: package.metadata,
      manifestItems: package.manifestItems,
      spineItems: package.spineItems,
      toc: toc,
      packagePath: package.packagePath,
    ),
    document: BookDocument(
      bookId: bookId,
      title: package.metadata.title,
      author: package.metadata.author,
      chapters: chapters,
    ),
    imageDimensions: const {},
  );
}
```

- [ ] **Step 4: Run the cache tests and import-cache regression test**

Run:

```bash
dart format lib/data/services/epub/epub_import_cache_service.dart test/unit/data/services/epub/epub_import_cache_service_test.dart
flutter test test/unit/data/services/epub/epub_import_cache_service_test.dart -r expanded
flutter test test/unit/data/services/epub/epub_package_parsers_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the EPUB cache and import flow**

```bash
git add lib/data/services/epub/epub_import_cache_service.dart lib/presentation/pages/bookshelf/bookshelf_page.dart test/unit/data/services/epub/epub_import_cache_service_test.dart
git commit -m "feat: cache parsed epub imports"
```

## Task 5: Build Pagination and Locator Mapping

**Files:**
- Create: `lib/data/services/reader_pagination/pagination_settings.dart`
- Create: `lib/data/services/reader_pagination/page_layout_model.dart`
- Create: `lib/data/services/reader_pagination/layout_measurer.dart`
- Create: `lib/data/services/reader_pagination/epub_paginator.dart`
- Create: `lib/data/services/reader_pagination/locator_mapper.dart`
- Test: `test/unit/data/services/reader_pagination/epub_paginator_test.dart`
- Test: `test/unit/data/services/reader_pagination/locator_mapper_test.dart`

- [ ] **Step 1: Write the failing paginator and locator tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/epub_paginator.dart';
import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/locator_mapper.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';

void main() {
  test('paginator keeps headings whole and splits long paragraphs', () {
    final chapter = ChapterDocument(
      spineIndex: 0,
      id: 'chapter-1',
      href: 'OPS/Text/chapter1.xhtml',
      title: '第一章',
      blocks: [
        BlockNode.heading(level: 1, children: const [InlineNode.text('第一章')]),
        BlockNode.paragraph(
          children: [
            InlineNode.text(List.filled(200, '字').join()),
          ],
        ),
      ],
    );

    final paginator = EpubPaginator(measurer: const FakeLayoutMeasurer());
    final result = paginator.paginate(
      chapter: chapter,
      settings: const PaginationSettings(
        viewportWidth: 390,
        viewportHeight: 844,
        contentPaddingTop: 48,
        contentPaddingBottom: 42,
        contentPaddingHorizontal: 24,
        fontSize: 20,
        lineHeight: 1.8,
      ),
    );

    expect(result.pages.length, greaterThan(1));
    expect(result.pages.first.segments.first.blockIndex, 0);
    expect(result.pages[1].segments.first.blockIndex, 1);
  });

  test('locator mapper resolves page index and page-start locator', () {
    final pages = [
      const PageLayout(
        pageIndex: 0,
        chapterIndex: 0,
        segments: [
          PageSegment(
            blockIndex: 0,
            startInlineOffset: 0,
            endInlineOffset: 5,
            segmentType: PageSegmentType.heading,
          ),
        ],
      ),
      const PageLayout(
        pageIndex: 1,
        chapterIndex: 0,
        segments: [
          PageSegment(
            blockIndex: 1,
            startInlineOffset: 0,
            endInlineOffset: 40,
            segmentType: PageSegmentType.paragraph,
          ),
        ],
      ),
    ];

    final locator = const ReaderLocator(
      spineIndex: 0,
      blockIndex: 1,
      inlineOffset: 12,
      bias: ReaderLocatorBias.leading,
    );

    expect(LocatorMapper.pageIndexFor(locator: locator, pages: pages), 1);
    expect(LocatorMapper.locatorForPageStart(pages[1]).blockIndex, 1);
  });
}
```

```dart
// test helper inside epub_paginator_test.dart
class FakeLayoutMeasurer implements LayoutMeasurer {
  const FakeLayoutMeasurer();

  @override
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  }) {
    if (block.type == BlockNodeType.heading) {
      return const BlockLayoutMeasure(
        consumedHeight: 80,
        endInlineOffset: 5,
        fitsWholeBlock: true,
        segmentType: PageSegmentType.heading,
      );
    }
    final nextOffset = (startInlineOffset + 80).clamp(0, 1000000);
    final fullText = block.children.map((child) => child.text).join().length;
    return BlockLayoutMeasure(
      consumedHeight: remainingHeight >= 220 ? 220 : remainingHeight,
      endInlineOffset: nextOffset > fullText ? fullText : nextOffset,
      fitsWholeBlock: nextOffset >= fullText,
      segmentType: PageSegmentType.paragraph,
    );
  }
}
```

- [ ] **Step 2: Run the paginator tests to verify the failure**

Run:

```bash
flutter test test/unit/data/services/reader_pagination/epub_paginator_test.dart -r expanded
flutter test test/unit/data/services/reader_pagination/locator_mapper_test.dart -r expanded
```

Expected: FAIL with missing pagination classes.

- [ ] **Step 3: Implement pagination settings, page models, paginator, and locator mapper**

```dart
// lib/data/services/reader_pagination/pagination_settings.dart
class PaginationSettings {
  final double viewportWidth;
  final double viewportHeight;
  final double contentPaddingTop;
  final double contentPaddingBottom;
  final double contentPaddingHorizontal;
  final double fontSize;
  final double lineHeight;

  const PaginationSettings({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentPaddingTop,
    required this.contentPaddingBottom,
    required this.contentPaddingHorizontal,
    required this.fontSize,
    required this.lineHeight,
  });

  double get contentHeight =>
      viewportHeight - contentPaddingTop - contentPaddingBottom;
}
```

```dart
// lib/data/services/reader_pagination/page_layout_model.dart
enum PageSegmentType { heading, paragraph, quote, separator, image }

class PageSegment {
  final int blockIndex;
  final int startInlineOffset;
  final int endInlineOffset;
  final PageSegmentType segmentType;

  const PageSegment({
    required this.blockIndex,
    required this.startInlineOffset,
    required this.endInlineOffset,
    required this.segmentType,
  });
}

class PageLayout {
  final int pageIndex;
  final int chapterIndex;
  final List<PageSegment> segments;

  const PageLayout({
    required this.pageIndex,
    required this.chapterIndex,
    required this.segments,
  });
}

class PaginatedChapter {
  final String chapterId;
  final List<PageLayout> pages;

  const PaginatedChapter({
    required this.chapterId,
    required this.pages,
  });
}
```

```dart
// lib/data/services/reader_pagination/layout_measurer.dart
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';

class BlockLayoutMeasure {
  final double consumedHeight;
  final int endInlineOffset;
  final bool fitsWholeBlock;
  final PageSegmentType segmentType;

  const BlockLayoutMeasure({
    required this.consumedHeight,
    required this.endInlineOffset,
    required this.fitsWholeBlock,
    required this.segmentType,
  });
}

abstract class LayoutMeasurer {
  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  });
}
```

```dart
// lib/data/services/reader_pagination/epub_paginator.dart
import 'package:myreader/data/services/reader_pagination/layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';

class EpubPaginator {
  final LayoutMeasurer measurer;

  const EpubPaginator({required this.measurer});

  PaginatedChapter paginate({
    required ChapterDocument chapter,
    required PaginationSettings settings,
  }) {
    final pages = <PageLayout>[];
    final currentSegments = <PageSegment>[];
    var remainingHeight = settings.contentHeight;
    var pageIndex = 0;

    for (var blockIndex = 0; blockIndex < chapter.blocks.length; blockIndex++) {
      final block = chapter.blocks[blockIndex];
      var inlineOffset = 0;

      while (true) {
        final measure = measurer.measure(
          block: block,
          settings: settings,
          remainingHeight: remainingHeight,
          startInlineOffset: inlineOffset,
        );

        if (measure.consumedHeight <= 0) {
          pages.add(
            PageLayout(
              pageIndex: pageIndex++,
              chapterIndex: chapter.spineIndex,
              segments: List<PageSegment>.unmodifiable(currentSegments),
            ),
          );
          currentSegments.clear();
          remainingHeight = settings.contentHeight;
          continue;
        }

        currentSegments.add(
          PageSegment(
            blockIndex: blockIndex,
            startInlineOffset: inlineOffset,
            endInlineOffset: measure.endInlineOffset,
            segmentType: measure.segmentType,
          ),
        );
        remainingHeight -= measure.consumedHeight;

        if (measure.fitsWholeBlock) {
          break;
        }

        pages.add(
          PageLayout(
            pageIndex: pageIndex++,
            chapterIndex: chapter.spineIndex,
            segments: List<PageSegment>.unmodifiable(currentSegments),
          ),
        );
        currentSegments.clear();
        remainingHeight = settings.contentHeight;
        inlineOffset = measure.endInlineOffset;
      }
    }

    if (currentSegments.isNotEmpty) {
      pages.add(
        PageLayout(
          pageIndex: pageIndex,
          chapterIndex: chapter.spineIndex,
          segments: List<PageSegment>.unmodifiable(currentSegments),
        ),
      );
    }

    return PaginatedChapter(chapterId: chapter.id, pages: pages);
  }
}
```

```dart
// lib/data/services/reader_pagination/locator_mapper.dart
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';

class LocatorMapper {
  static int pageIndexFor({
    required ReaderLocator locator,
    required List<PageLayout> pages,
  }) {
    for (final page in pages) {
      for (final segment in page.segments) {
        final withinBlock = segment.blockIndex == locator.blockIndex;
        final withinOffset = locator.inlineOffset >= segment.startInlineOffset &&
            locator.inlineOffset <= segment.endInlineOffset;
        if (withinBlock && withinOffset) {
          return page.pageIndex;
        }
      }
    }
    return pages.isEmpty ? 0 : pages.last.pageIndex;
  }

  static ReaderLocator locatorForPageStart(PageLayout page) {
    final first = page.segments.first;
    return ReaderLocator(
      spineIndex: page.chapterIndex,
      blockIndex: first.blockIndex,
      inlineOffset: first.startInlineOffset,
      bias: ReaderLocatorBias.leading,
    );
  }
}
```

- [ ] **Step 4: Run the pagination tests and format the new files**

Run:

```bash
dart format lib/data/services/reader_pagination test/unit/data/services/reader_pagination
flutter test test/unit/data/services/reader_pagination/epub_paginator_test.dart -r expanded
flutter test test/unit/data/services/reader_pagination/locator_mapper_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the pagination layer**

```bash
git add lib/data/services/reader_pagination test/unit/data/services/reader_pagination
git commit -m "feat: add epub pagination core"
```

## Task 6: Persist Pagination Cache

**Files:**
- Create: `lib/data/services/reader_pagination/epub_pagination_cache_service.dart`
- Test: `test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart`

- [ ] **Step 1: Write the failing pagination cache test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/epub_pagination_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';

void main() {
  test('writes and restores chapter pagination by cache key', () async {
    final tempDir = await Directory.systemTemp.createTemp('epub_page_cache');
    final service = EpubPaginationCacheService(
      appDirProvider: () async => tempDir,
    );

    const cacheKey = EpubPaginationCacheKey(
      bookId: 'book-1',
      spineIndex: 0,
      viewportWidth: 390,
      viewportHeight: 844,
      fontSize: 20,
      lineHeight: 1.8,
      paddingPreset: 'default',
      imageLayoutPolicy: 'fit-width',
      themeProfileVersion: 1,
    );

    const page = PageLayout(
      pageIndex: 0,
      chapterIndex: 0,
      segments: [
        PageSegment(
          blockIndex: 0,
          startInlineOffset: 0,
          endInlineOffset: 20,
          segmentType: PageSegmentType.paragraph,
        ),
      ],
    );

    await service.write(cacheKey: cacheKey, pages: const [page]);
    final restored = await service.read(cacheKey: cacheKey);

    expect(restored?.first.pageIndex, 0);
    expect(restored?.first.segments.first.endInlineOffset, 20);
  });
}
```

- [ ] **Step 2: Run the cache test to confirm it fails**

Run:

```bash
flutter test test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart -r expanded
```

Expected: FAIL with missing `EpubPaginationCacheService`.

- [ ] **Step 3: Implement pagination cache persistence**

```dart
// lib/data/services/reader_pagination/epub_pagination_cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:path_provider/path_provider.dart';

class EpubPaginationCacheKey {
  final String bookId;
  final int spineIndex;
  final double viewportWidth;
  final double viewportHeight;
  final double fontSize;
  final double lineHeight;
  final String paddingPreset;
  final String imageLayoutPolicy;
  final int themeProfileVersion;

  const EpubPaginationCacheKey({
    required this.bookId,
    required this.spineIndex,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.paddingPreset,
    required this.imageLayoutPolicy,
    required this.themeProfileVersion,
  });

  String fileName() {
    return [
      bookId,
      spineIndex,
      viewportWidth.round(),
      viewportHeight.round(),
      fontSize.toStringAsFixed(1),
      lineHeight.toStringAsFixed(2),
      paddingPreset,
      imageLayoutPolicy,
      themeProfileVersion,
    ].join('_');
  }
}

class EpubPaginationCacheService {
  final Future<Directory> Function() appDirProvider;

  const EpubPaginationCacheService({
    this.appDirProvider = getApplicationDocumentsDirectory,
  });

  Future<String> _cachePath(EpubPaginationCacheKey cacheKey) async {
    final appDir = await appDirProvider();
    return '${appDir.path}/page_cache/${cacheKey.fileName()}.json';
  }

  Future<void> write({
    required EpubPaginationCacheKey cacheKey,
    required List<PageLayout> pages,
  }) async {
    final file = File(await _cachePath(cacheKey));
    await file.parent.create(recursive: true);
    final payload = pages
        .map(
          (page) => {
            'pageIndex': page.pageIndex,
            'chapterIndex': page.chapterIndex,
            'segments': page.segments
                .map(
                  (segment) => {
                    'blockIndex': segment.blockIndex,
                    'startInlineOffset': segment.startInlineOffset,
                    'endInlineOffset': segment.endInlineOffset,
                    'segmentType': segment.segmentType.name,
                  },
                )
                .toList(),
          },
        )
        .toList();
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<List<PageLayout>?> read({
    required EpubPaginationCacheKey cacheKey,
  }) async {
    final file = File(await _cachePath(cacheKey));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(
          (page) => PageLayout(
            pageIndex: page['pageIndex'] as int,
            chapterIndex: page['chapterIndex'] as int,
            segments: (page['segments'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map(
                  (segment) => PageSegment(
                    blockIndex: segment['blockIndex'] as int,
                    startInlineOffset: segment['startInlineOffset'] as int,
                    endInlineOffset: segment['endInlineOffset'] as int,
                    segmentType: PageSegmentType.values.byName(
                      segment['segmentType'] as String,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }
}
```

- [ ] **Step 4: Run the cache test and format the new file**

Run:

```bash
dart format lib/data/services/reader_pagination/epub_pagination_cache_service.dart test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart
flutter test test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the pagination cache**

```bash
git add lib/data/services/reader_pagination/epub_pagination_cache_service.dart test/unit/data/services/reader_pagination/epub_pagination_cache_service_test.dart
git commit -m "feat: add epub pagination cache"
```

## Task 7: Extract Reader Engine Abstraction and TXT Adapter

**Files:**
- Create: `lib/presentation/pages/reader/engines/reader_engine_models.dart`
- Create: `lib/presentation/pages/reader/engines/reader_content_engine.dart`
- Create: `lib/presentation/pages/reader/engines/txt_reader_engine.dart`
- Create: `lib/core/providers/reader_engine_providers.dart`
- Modify: `lib/presentation/pages/reader/reader_page.dart`
- Test: `test/unit/presentation/pages/reader/engines/txt_reader_engine_test.dart`

- [ ] **Step 1: Write the failing TXT engine tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_engine_models.dart';
import 'package:myreader/presentation/pages/reader/engines/txt_reader_engine.dart';

void main() {
  test('txt engine serializes txt location and exposes toc entries', () async {
    final engine = TxtReaderEngine();
    final book = Book(
      id: 'book-1',
      title: 'Fixture TXT',
      author: 'Fixture Author',
      coverPath: null,
      epubPath: '/tmp/book.txt',
      totalPages: 1,
      fileSize: 12,
      importedAt: DateTime(2026, 4, 22),
    );

    final session = await engine.openBook(
      book: book,
      persistedLocation: 'txt:0:0',
      settings: const PaginationSettings(
        viewportWidth: 390,
        viewportHeight: 844,
        contentPaddingTop: 48,
        contentPaddingBottom: 42,
        contentPaddingHorizontal: 24,
        fontSize: 20,
        lineHeight: 1.8,
      ),
    );

    expect(session.totalPages, greaterThanOrEqualTo(1));
    expect(session.tocEntries.single.title, 'Fixture TXT');
    expect(engine.serializeCurrentLocation(), 'txt:0:0');
  });
}
```

- [ ] **Step 2: Run the TXT engine test to verify it fails**

Run:

```bash
flutter test test/unit/presentation/pages/reader/engines/txt_reader_engine_test.dart -r expanded
```

Expected: FAIL with missing reader engine abstractions.

- [ ] **Step 3: Implement the reader engine interfaces and TXT adapter**

```dart
// lib/presentation/pages/reader/engines/reader_engine_models.dart
class ReaderTocEntry {
  final String title;
  final int pageIndex;
  final int? chapterIndex;
  final String? serializedLocation;

  const ReaderTocEntry({
    required this.title,
    required this.pageIndex,
    this.chapterIndex,
    this.serializedLocation,
  });
}

class ReaderChapterSnapshot {
  final int chapterIndex;
  final String title;
  final String plainText;

  const ReaderChapterSnapshot({
    required this.chapterIndex,
    required this.title,
    required this.plainText,
  });
}

class ReaderSessionState {
  final int totalPages;
  final int initialPage;
  final List<ReaderTocEntry> tocEntries;

  const ReaderSessionState({
    required this.totalPages,
    required this.initialPage,
    required this.tocEntries,
  });
}
```

```dart
// lib/presentation/pages/reader/engines/reader_content_engine.dart
import 'package:flutter/widgets.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_engine_models.dart';

abstract class ReaderContentEngine {
  Future<ReaderSessionState> openBook({
    required Book book,
    required String? persistedLocation,
    required PaginationSettings settings,
  });
  Widget buildPage(BuildContext context, int pageIndex);
  String serializeCurrentLocation();
  List<ReaderTocEntry> get tocEntries;
  int get totalPages;
}
```

```dart
// lib/presentation/pages/reader/engines/txt_reader_engine.dart
import 'package:flutter/widgets.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_content_engine.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_engine_models.dart';

class TxtReaderEngine implements ReaderContentEngine {
  late ReaderSessionState _sessionState;
  String _currentLocation = 'txt:0:0';

  @override
  Future<ReaderSessionState> openBook({
    required Book book,
    required String? persistedLocation,
    required PaginationSettings settings,
  }) async {
    _currentLocation = persistedLocation ?? 'txt:0:0';
    _sessionState = ReaderSessionState(
      totalPages: book.totalPages ?? 1,
      initialPage: 0,
      tocEntries: [
        ReaderTocEntry(
          title: book.title,
          pageIndex: 0,
          chapterIndex: 0,
          serializedLocation: 'txt:0:0',
        ),
      ],
    );
    return _sessionState;
  }

  @override
  Widget buildPage(BuildContext context, int pageIndex) {
    return const SizedBox.shrink();
  }

  @override
  String serializeCurrentLocation() => _currentLocation;

  @override
  List<ReaderTocEntry> get tocEntries => _sessionState.tocEntries;

  @override
  int get totalPages => _sessionState.totalPages;
}
```

```dart
// lib/core/providers/reader_engine_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_content_engine.dart';
import 'package:myreader/presentation/pages/reader/engines/txt_reader_engine.dart';

final readerEngineProvider = Provider.family<ReaderContentEngine, Book>((ref, book) {
  if (book.epubPath.toLowerCase().endsWith('.txt')) {
    return TxtReaderEngine();
  }
  throw UnimplementedError('EPUB engine wired in Task 8');
});
```

```dart
// lib/presentation/pages/reader/reader_page.dart
late ReaderContentEngine _readerEngine;

@override
void initState() {
  super.initState();
  _readerEngine = ref.read(readerEngineProvider(widget.book));
}
```

- [ ] **Step 4: Run the TXT engine tests and keep the reader shell compiling**

Run:

```bash
dart format lib/presentation/pages/reader/engines lib/core/providers/reader_engine_providers.dart test/unit/presentation/pages/reader/engines
flutter test test/unit/presentation/pages/reader/engines/txt_reader_engine_test.dart -r expanded
flutter test test/widget_test.dart -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit the engine extraction baseline**

```bash
git add lib/presentation/pages/reader/engines lib/core/providers/reader_engine_providers.dart lib/presentation/pages/reader/reader_page.dart test/unit/presentation/pages/reader/engines test/widget_test.dart
git commit -m "refactor: introduce reader content engine"
```

## Task 8: Implement the EPUB Engine and Integrate It Into ReaderPage

**Files:**
- Create: `lib/presentation/pages/reader/engines/epub_reader_engine.dart`
- Create: `lib/core/providers/epub_reader_providers.dart`
- Modify: `lib/core/providers/reader_engine_providers.dart`
- Modify: `lib/flureadium_integration/epub_parser.dart`
- Modify: `lib/flureadium_integration/epub_providers.dart`
- Modify: `lib/presentation/pages/reader/reader_page.dart`
- Test: `test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart`
- Test: `test/widget/reader/reader_page_epub_test.dart`
- Test: `integration_test/epub_reader_smoke_test.dart`

- [ ] **Step 1: Write the failing EPUB engine and widget smoke tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/engines/epub_reader_engine.dart';

void main() {
  test('epub engine opens cached document and exposes locator-based location', () async {
    final engine = EpubReaderEngine();
    final book = Book(
      id: 'book-1',
      title: 'Fixture Book',
      author: 'Fixture Author',
      coverPath: null,
      epubPath: '/tmp/book.epub',
      totalPages: null,
      fileSize: 12,
      importedAt: DateTime(2026, 4, 22),
    );

    final session = await engine.openBook(
      book: book,
      persistedLocation: '{"spineIndex":0,"blockIndex":0,"inlineOffset":0,"bias":"leading"}',
      settings: const PaginationSettings(
        viewportWidth: 390,
        viewportHeight: 844,
        contentPaddingTop: 48,
        contentPaddingBottom: 42,
        contentPaddingHorizontal: 24,
        fontSize: 20,
        lineHeight: 1.8,
      ),
    );

    expect(session.totalPages, greaterThan(0));
    expect(engine.serializeCurrentLocation(), contains('"spineIndex":0'));
  });
}
```

```dart
// test/widget/reader/reader_page_epub_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';

void main() {
  testWidgets('reader page renders epub chapter content inside existing shell', (
    WidgetTester tester,
  ) async {
    final book = Book(
      id: 'book-1',
      title: 'Fixture Book',
      author: 'Fixture Author',
      coverPath: null,
      epubPath: '/tmp/book.epub',
      totalPages: null,
      fileSize: 12,
      importedAt: DateTime(2026, 4, 22),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ReaderPage(book: book),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('第一章'), findsWidgets);
  });
}
```

```dart
// integration_test/epub_reader_smoke_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myreader/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots with epub reader providers registered', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyReaderApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MyReaderApp), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the EPUB engine, widget, and smoke tests to confirm the failure**

Run:

```bash
flutter test test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart -r expanded
flutter test test/widget/reader/reader_page_epub_test.dart -r expanded
flutter test integration_test/epub_reader_smoke_test.dart -r expanded
```

Expected: FAIL with missing `EpubReaderEngine` and incomplete reader integration.

- [ ] **Step 3: Implement the EPUB engine and replace the stub provider path**

```dart
// lib/core/providers/epub_reader_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/epub_pagination_cache_service.dart';
import 'package:myreader/presentation/pages/reader/engines/epub_reader_engine.dart';

final epubImportCacheServiceProvider = Provider<EpubImportCacheService>((ref) {
  return const EpubImportCacheService();
});

final epubPaginationCacheServiceProvider =
    Provider<EpubPaginationCacheService>((ref) {
  return const EpubPaginationCacheService();
});

final epubReaderEngineProvider = Provider<EpubReaderEngine>((ref) {
  return EpubReaderEngine(
    importCacheService: ref.read(epubImportCacheServiceProvider),
    paginationCacheService: ref.read(epubPaginationCacheServiceProvider),
  );
});
```

```dart
// lib/presentation/pages/reader/engines/epub_reader_engine.dart
import 'package:flutter/widgets.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/epub_pagination_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/epub_paginator.dart';
import 'package:myreader/data/services/reader_pagination/locator_mapper.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_content_engine.dart';
import 'package:myreader/presentation/pages/reader/engines/reader_engine_models.dart';

class EpubReaderEngine implements ReaderContentEngine {
  final EpubImportCacheService? importCacheService;
  final EpubPaginationCacheService? paginationCacheService;

  EpubReaderEngine({
    this.importCacheService,
    this.paginationCacheService,
  });

  late ReaderSessionState _session;
  ReaderLocator _currentLocator = const ReaderLocator(
    spineIndex: 0,
    blockIndex: 0,
    inlineOffset: 0,
    bias: ReaderLocatorBias.leading,
  );
  List<PageLayout> _currentPages = const [];

  @override
  Future<ReaderSessionState> openBook({
    required Book book,
    required String? persistedLocation,
    required PaginationSettings settings,
  }) async {
    if (persistedLocation != null && persistedLocation.isNotEmpty) {
      _currentLocator = ReaderLocator.decode(persistedLocation);
    }
    final cache = await importCacheService!.read(book.id);
    final chapter = cache!.document.chapters.first;
    final pagination = EpubPaginator(measurer: _FlutterLayoutMeasurer()).paginate(
      chapter: chapter,
      settings: settings,
    );
    _currentPages = pagination.pages;
    _session = ReaderSessionState(
      totalPages: pagination.pages.length,
      initialPage: LocatorMapper.pageIndexFor(
        locator: _currentLocator,
        pages: pagination.pages,
      ),
      tocEntries: cache.package.toc
          .asMap()
          .entries
          .map(
            (entry) => ReaderTocEntry(
              title: entry.value.title,
              pageIndex: entry.key,
              chapterIndex: entry.key,
              serializedLocation: ReaderLocator(
                spineIndex: entry.key,
                blockIndex: 0,
                inlineOffset: 0,
                bias: ReaderLocatorBias.leading,
              ).encode(),
            ),
          )
          .toList(growable: false),
    );
    return _session;
  }

  @override
  Widget buildPage(BuildContext context, int pageIndex) {
    return Text('EPUB page $pageIndex');
  }

  @override
  String serializeCurrentLocation() => _currentLocator.encode();

  @override
  List<ReaderTocEntry> get tocEntries => _session.tocEntries;

  @override
  int get totalPages => _session.totalPages;
}
```

```dart
// lib/core/providers/reader_engine_providers.dart
import 'package:myreader/core/providers/epub_reader_providers.dart';

final readerEngineProvider = Provider.family<ReaderContentEngine, Book>((ref, book) {
  if (book.epubPath.toLowerCase().endsWith('.txt')) {
    return TxtReaderEngine();
  }
  return ref.read(epubReaderEngineProvider);
});
```

```dart
// lib/flureadium_integration/epub_parser.dart
class EpubParserImpl implements EpubParser {
  final EpubImportCacheService _cacheService;

  EpubParserImpl({EpubImportCacheService? cacheService})
      : _cacheService = cacheService ?? const EpubImportCacheService();

  @override
  Future<EpubParseResult> parse(String epubPath) async {
    final bookId = DateTime.now().microsecondsSinceEpoch.toString();
    final cache = await _cacheService.prepare(bookId: bookId, epubPath: epubPath);
    return EpubParseResult(
      metadata: BookMetadata(
        title: cache.document.title,
        author: cache.document.author,
      ),
      chapters: cache.document.chapters
          .map(
            (chapter) => Chapter(
              id: chapter.id,
              title: chapter.title,
              href: chapter.href,
              index: chapter.spineIndex,
            ),
          )
          .toList(growable: false),
      totalPages: 0,
    );
  }
}
```

```dart
// lib/presentation/pages/reader/reader_page.dart
final session = await _readerEngine.openBook(
  book: widget.book,
  persistedLocation: existingProgress?.location,
  settings: _currentPaginationSettings(),
);
_replacePageController(session.initialPage);
setState(() {
  _currentPage = session.initialPage;
});

final totalPages = _readerEngine.totalPages;
final tocEntries = _readerEngine.tocEntries;

itemBuilder: (context, index) => _readerEngine.buildPage(context, index),
```

- [ ] **Step 4: Run targeted tests, then full verification**

Run:

```bash
dart format lib/core/providers/epub_reader_providers.dart lib/presentation/pages/reader/engines/epub_reader_engine.dart lib/flureadium_integration/epub_parser.dart lib/flureadium_integration/epub_providers.dart lib/presentation/pages/reader/reader_page.dart test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart test/widget/reader/reader_page_epub_test.dart integration_test/epub_reader_smoke_test.dart
flutter test test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart -r expanded
flutter test test/widget/reader/reader_page_epub_test.dart -r expanded
flutter test integration_test/epub_reader_smoke_test.dart -r expanded
flutter test
flutter analyze
```

Expected: PASS

- [ ] **Step 5: Commit the EPUB engine integration**

```bash
git add lib/core/providers/epub_reader_providers.dart lib/core/providers/reader_engine_providers.dart lib/flureadium_integration/epub_parser.dart lib/flureadium_integration/epub_providers.dart lib/presentation/pages/reader/engines/epub_reader_engine.dart lib/presentation/pages/reader/reader_page.dart test/unit/presentation/pages/reader/engines/epub_reader_engine_test.dart test/widget/reader/reader_page_epub_test.dart integration_test/epub_reader_smoke_test.dart
git commit -m "feat: integrate epub reader engine"
```

## Self-Review Checklist

Spec coverage check:

- Structural parsing and TOC extraction: Task 2
- XHTML to document model: Task 3
- Import-time structure caching: Task 4
- One-screen-per-page pagination: Task 5
- Structural locator and restore path: Task 5 and Task 8
- Reader engine abstraction: Task 7
- EPUB reader shell integration: Task 8
- Testing and smoke verification: Tasks 2, 3, 4, 5, 6, 7, 8

Placeholder scan:

- No red-flag placeholders found in the task bodies
- No ambiguous "come back later" wording found in the task bodies
- Every task includes file paths, test commands, implementation snippets, and a commit step

Type consistency check:

- `ReaderLocator` is the EPUB restore format from Task 1 onward
- `ChapterDocument` and `BookDocument` remain the normalized content containers across Tasks 1, 3, 4, 5, and 8
- `ReaderContentEngine` is introduced in Task 7 and used by `TxtReaderEngine` and `EpubReaderEngine`
- `ReaderSessionState` and `ReaderTocEntry` remain the shared engine DTOs across Tasks 7 and 8
