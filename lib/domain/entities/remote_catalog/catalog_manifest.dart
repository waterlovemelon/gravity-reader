class CatalogManifest {
  final String bookId;
  final String version;
  final String title;
  final String author;
  final List<CatalogManifestChapter> chapters;

  const CatalogManifest({
    required this.bookId,
    required this.version,
    required this.title,
    required this.author,
    required this.chapters,
  });
}

class CatalogManifestChapter {
  final String id;
  final String title;
  final int order;
  final int wordCount;

  const CatalogManifestChapter({
    required this.id,
    required this.title,
    required this.order,
    required this.wordCount,
  });
}
