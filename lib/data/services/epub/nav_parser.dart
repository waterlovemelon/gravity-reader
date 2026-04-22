import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:xml/xml.dart';

class NavParser {
  List<EpubTocEntry> parseNav({
    required String navXml,
    required String navPath,
  }) {
    final document = XmlDocument.parse(navXml);
    final toc = <EpubTocEntry>[];
    for (final anchor in document.descendants.whereType<XmlElement>()) {
      if (anchor.name.local != 'a') {
        continue;
      }
      final title = anchor.innerText.trim();
      final href = anchor.getAttribute('href');
      if (title.isEmpty || href == null || href.isEmpty) {
        continue;
      }
      toc.add(
        EpubTocEntry(
          title: title,
          href: EpubArchiveService().resolvePath(
            basePath: navPath,
            relativePath: href,
          ),
        ),
      );
    }
    return List<EpubTocEntry>.unmodifiable(toc);
  }
}
