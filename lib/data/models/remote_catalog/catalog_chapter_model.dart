import 'package:myreader/domain/entities/remote_catalog/catalog_chapter.dart';

class CatalogChapterModel {
  final String bookId;
  final String chapterId;
  final String title;
  final String contentType;
  final String text;
  final String? nextChapterId;
  final String? prevChapterId;

  const CatalogChapterModel({
    required this.bookId,
    required this.chapterId,
    required this.title,
    required this.contentType,
    required this.text,
    this.nextChapterId,
    this.prevChapterId,
  });

  factory CatalogChapterModel.fromJson(Map<String, dynamic> json) {
    return CatalogChapterModel(
      bookId: json['book_id'] as String,
      chapterId: json['chapter_id'] as String,
      title: json['title'] as String,
      contentType: json['content_type'] as String,
      text: json['text'] as String,
      nextChapterId: json['next_chapter_id'] as String?,
      prevChapterId: json['prev_chapter_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'chapter_id': chapterId,
      'title': title,
      'content_type': contentType,
      'text': text,
      'next_chapter_id': nextChapterId,
      'prev_chapter_id': prevChapterId,
    };
  }

  CatalogChapter toEntity() {
    return CatalogChapter(
      bookId: bookId,
      chapterId: chapterId,
      title: title,
      contentType: contentType,
      text: text,
      nextChapterId: nextChapterId,
      prevChapterId: prevChapterId,
    );
  }
}
