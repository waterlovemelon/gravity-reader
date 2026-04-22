class EpubMetadata {
  final String title;
  final String? author;
  final String? coverId;

  const EpubMetadata({required this.title, this.author, this.coverId});

  factory EpubMetadata.fromJson(Map<String, dynamic> json) {
    return EpubMetadata(
      title: json['title'] as String,
      author: json['author'] as String?,
      coverId: json['coverId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'author': author, 'coverId': coverId};
  }
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

  factory EpubManifestItem.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as List<dynamic>? ?? const [];
    return EpubManifestItem(
      id: json['id'] as String,
      href: json['href'] as String,
      mediaType: json['mediaType'] as String,
      properties: properties.cast<String>().toSet(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'href': href,
      'mediaType': mediaType,
      'properties': properties.toList()..sort(),
    };
  }
}

class EpubSpineItem {
  final String idref;
  final int index;

  const EpubSpineItem({required this.idref, required this.index});

  factory EpubSpineItem.fromJson(Map<String, dynamic> json) {
    return EpubSpineItem(
      idref: json['idref'] as String,
      index: json['index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'idref': idref, 'index': index};
  }
}

class EpubTocEntry {
  final String title;
  final String href;

  const EpubTocEntry({required this.title, required this.href});

  factory EpubTocEntry.fromJson(Map<String, dynamic> json) {
    return EpubTocEntry(
      title: json['title'] as String,
      href: json['href'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'href': href};
  }
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

  factory EpubPackage.fromJson(Map<String, dynamic> json) {
    final manifestItems =
        json['manifestItems'] as Map<String, dynamic>? ?? const {};
    final spineItems = json['spineItems'] as List<dynamic>? ?? const [];
    final toc = json['toc'] as List<dynamic>? ?? const [];
    return EpubPackage(
      metadata: EpubMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      manifestItems: {
        for (final entry in manifestItems.entries)
          entry.key: EpubManifestItem.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      spineItems: spineItems
          .cast<Map<String, dynamic>>()
          .map(EpubSpineItem.fromJson)
          .toList(growable: false),
      toc: toc
          .cast<Map<String, dynamic>>()
          .map(EpubTocEntry.fromJson)
          .toList(growable: false),
      packagePath: json['packagePath'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'manifestItems': {
        for (final entry in manifestItems.entries)
          entry.key: entry.value.toJson(),
      },
      'spineItems': spineItems.map((item) => item.toJson()).toList(),
      'toc': toc.map((entry) => entry.toJson()).toList(),
      'packagePath': packagePath,
    };
  }
}
