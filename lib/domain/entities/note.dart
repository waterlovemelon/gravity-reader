// Note entity - Clean Architecture Domain Layer
// Represents a note/highlight in the reading application

class Note {
  final String id;
  final String bookId;
  final String content;
  final String? cfi; // CFI (Content Fragment Identifier) for EPUB location
  final String? textSelection; // The selected text that was highlighted/noted
  final int color; // Highlight color index (0-5)
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.bookId,
    required this.content,
    this.cfi,
    this.textSelection,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  String toString() => 'Note(id: $id, bookId: $bookId, content: $content)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
