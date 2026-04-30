import 'package:myreader/domain/entities/reader_document/chapter_document.dart';

class BookDocument {
  final String bookId;
  final String title;
  final String? author;
  final String? language;
  final List<ChapterDocument> chapters;

  const BookDocument({
    required this.bookId,
    required this.title,
    this.author,
    this.language,
    required this.chapters,
  });

  factory BookDocument.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List<dynamic>? ?? const [];
    return BookDocument(
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      language: json['language'] as String?,
      chapters: chaptersJson
          .cast<Map<String, dynamic>>()
          .map(ChapterDocument.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'author': author,
      'language': language,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }
}
