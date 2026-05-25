class CatalogBookSummary {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String downloadUrl;
  final String language;
  final int chapterCount;

  const CatalogBookSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
    required this.language,
    required this.chapterCount,
  });
}

class CatalogBookDetail {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String downloadUrl;
  final String language;
  final int chapterCount;

  const CatalogBookDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
    required this.language,
    required this.chapterCount,
  });
}
