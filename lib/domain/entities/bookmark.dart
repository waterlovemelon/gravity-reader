// Bookmark entity - Clean Architecture Domain Layer
// Represents a bookmark in a book

class Bookmark {
  final String id;
  final String bookId;
  final String title;
  final String? cfi; // CFI (Content Fragment Identifier) for EPUB location
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.title,
    this.cfi,
    required this.createdAt,
  });

  @override
  String toString() => 'Bookmark(id: $id, bookId: $bookId, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
