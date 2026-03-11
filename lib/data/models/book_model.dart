// Book Model - Data Layer
// Maps between Book entity and database

import 'package:myreader/domain/entities/book.dart';

class BookModel {
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

  BookModel({
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

  factory BookModel.fromEntity(Book book) {
    return BookModel(
      id: book.id,
      title: book.title,
      author: book.author,
      coverPath: book.coverPath,
      epubPath: book.epubPath,
      totalPages: book.totalPages,
      fileSize: book.fileSize,
      importedAt: book.importedAt,
      lastReadAt: book.lastReadAt,
      categoryId: book.categoryId,
    );
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      coverPath: map['cover_path'] as String?,
      epubPath: map['epub_path'] as String,
      totalPages: map['total_pages'] as int?,
      fileSize: map['file_size'] as int,
      importedAt: DateTime.parse(map['imported_at'] as String),
      lastReadAt: map['last_read_at'] != null
          ? DateTime.parse(map['last_read_at'] as String)
          : null,
      categoryId: map['category_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_path': coverPath,
      'epub_path': epubPath,
      'total_pages': totalPages,
      'file_size': fileSize,
      'imported_at': importedAt.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'category_id': categoryId,
    };
  }

  Book toEntity() {
    return Book(
      id: id,
      title: title,
      author: author,
      coverPath: coverPath,
      epubPath: epubPath,
      totalPages: totalPages,
      fileSize: fileSize,
      importedAt: importedAt,
      lastReadAt: lastReadAt,
      categoryId: categoryId,
    );
  }
}
