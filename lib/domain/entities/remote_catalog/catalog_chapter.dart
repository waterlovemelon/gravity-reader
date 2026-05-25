class CatalogChapter {
  final String bookId;
  final String chapterId;
  final String title;
  final String contentType;
  final String text;
  final String? nextChapterId;
  final String? prevChapterId;

  const CatalogChapter({
    required this.bookId,
    required this.chapterId,
    required this.title,
    required this.contentType,
    required this.text,
    this.nextChapterId,
    this.prevChapterId,
  });
}
