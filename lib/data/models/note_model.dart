// Note Model - Data Layer
// Maps between Note entity and database

import 'package:myreader/domain/entities/note.dart';

class NoteModel {
  final String id;
  final String bookId;
  final String content;
  final String? cfi;
  final String? textSelection;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.bookId,
    required this.content,
    this.cfi,
    this.textSelection,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      bookId: note.bookId,
      content: note.content,
      cfi: note.cfi,
      textSelection: note.textSelection,
      color: note.color,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      content: map['content'] as String,
      cfi: map['cfi'] as String?,
      textSelection: map['text_selection'] as String?,
      color: map['color'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'content': content,
      'cfi': cfi,
      'text_selection': textSelection,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Note toEntity() {
    return Note(
      id: id,
      bookId: bookId,
      content: content,
      cfi: cfi,
      textSelection: textSelection,
      color: color,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
