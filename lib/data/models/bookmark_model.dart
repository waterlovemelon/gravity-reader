// Bookmark Model - Data Layer
// Maps between Bookmark entity and database

import 'package:myreader/domain/entities/bookmark.dart';

class BookmarkModel {
  final String id;
  final String bookId;
  final String title;
  final String? cfi;
  final DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.bookId,
    required this.title,
    this.cfi,
    required this.createdAt,
  });

  factory BookmarkModel.fromEntity(Bookmark bookmark) {
    return BookmarkModel(
      id: bookmark.id,
      bookId: bookmark.bookId,
      title: bookmark.title,
      cfi: bookmark.cfi,
      createdAt: bookmark.createdAt,
    );
  }

  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      title: map['title'] as String,
      cfi: map['cfi'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'cfi': cfi,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Bookmark toEntity() {
    return Bookmark(
      id: id,
      bookId: bookId,
      title: title,
      cfi: cfi,
      createdAt: createdAt,
    );
  }
}
