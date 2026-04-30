import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:xml/xml.dart';

class NavParser {
  const NavParser();

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

  List<EpubTocEntry> parseNcx({
    required String ncxXml,
    required String ncxPath,
  }) {
    final document = XmlDocument.parse(ncxXml);
    final toc = <EpubTocEntry>[];
    for (final navPoint in document.descendants.whereType<XmlElement>()) {
      if (navPoint.name.local != 'navPoint') {
        continue;
      }
      final title = navPoint.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'text')
          .map((element) => element.innerText.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      final href = navPoint.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 'content')
          .map((element) => element.getAttribute('src') ?? '')
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (title.isEmpty || href.isEmpty) {
        continue;
      }
      toc.add(
        EpubTocEntry(
          title: title,
          href: EpubArchiveService().resolvePath(
            basePath: ncxPath,
            relativePath: href,
          ),
        ),
      );
    }
    return List<EpubTocEntry>.unmodifiable(toc);
  }
}
