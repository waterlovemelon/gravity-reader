import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:xml/xml.dart';

class OpfParser {
  const OpfParser();

  EpubPackage parse({required String opfXml, required String packagePath}) {
    final document = XmlDocument.parse(opfXml);
    final metadataNode = _firstElementByLocalName(document, 'metadata');
    final manifestNode = _firstElementByLocalName(document, 'manifest');
    final spineNode = _firstElementByLocalName(document, 'spine');

    final manifestItems = <String, EpubManifestItem>{};
    for (final item in manifestNode.childElements.where(
      (element) => element.name.local == 'item',
    )) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) {
        continue;
      }
      final properties = (item.getAttribute('properties') ?? '')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .toSet();
      manifestItems[id] = EpubManifestItem(
        id: id,
        href: EpubArchiveService().resolvePath(
          basePath: packagePath,
          relativePath: href,
        ),
        mediaType: mediaType,
        properties: properties,
      );
    }

    final spineItems = <EpubSpineItem>[];
    for (final entry in spineNode.childElements.where(
      (element) => element.name.local == 'itemref',
    )) {
      final idref = entry.getAttribute('idref');
      if (idref == null || idref.isEmpty) {
        continue;
      }
      spineItems.add(EpubSpineItem(idref: idref, index: spineItems.length));
    }

    return EpubPackage(
      metadata: EpubMetadata(
        title: _firstTextByLocalName(metadataNode, 'title') ?? 'Untitled',
        author: _firstTextByLocalName(metadataNode, 'creator'),
        coverId: metadataNode.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'meta')
            .firstWhere(
              (element) => element.getAttribute('name') == 'cover',
              orElse: () => XmlElement(XmlName('meta')),
            )
            .getAttribute('content'),
      ),
      manifestItems: manifestItems,
      spineItems: List<EpubSpineItem>.unmodifiable(spineItems),
      toc: const [],
      packagePath: packagePath,
    );
  }

  XmlElement _firstElementByLocalName(XmlDocument document, String localName) {
    return document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == localName,
    );
  }

  String? _firstTextByLocalName(XmlElement root, String localName) {
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local != localName) {
        continue;
      }
      final value = element.innerText.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
