// Book entity - Clean Architecture Domain Layer
// Represents a book in the reading application

class Book {
  final String id;
  final String title;
  final String? author;
  final String? coverPath;
  final String epubPath;
  final int? totalPages;
  final int fileSize;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  final String? categoryId;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    required this.epubPath,
    this.totalPages,
    required this.fileSize,
    required this.importedAt,
    this.lastReadAt,
    this.categoryId,
  });

  @override
  String toString() => 'Book(id: $id, title: $title, author: $author)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
