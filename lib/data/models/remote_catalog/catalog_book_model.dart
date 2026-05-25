import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';

class CatalogBookSummaryModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String downloadUrl;
  final String language;
  final int chapterCount;

  const CatalogBookSummaryModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
    required this.language,
    required this.chapterCount,
  });

  factory CatalogBookSummaryModel.fromJson(Map<String, dynamic> json) {
    return CatalogBookSummaryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String,
      coverUrl: json['cover_url'] as String,
      downloadUrl: json['download_url'] as String,
      language: json['language'] as String,
      chapterCount: json['chapter_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'cover_url': coverUrl,
      'download_url': downloadUrl,
      'language': language,
      'chapter_count': chapterCount,
    };
  }

  CatalogBookSummary toEntity() {
    return CatalogBookSummary(
      id: id,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      downloadUrl: downloadUrl,
      language: language,
      chapterCount: chapterCount,
    );
  }
}

class CatalogBookDetailModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String downloadUrl;
  final String language;
  final int chapterCount;

  const CatalogBookDetailModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.downloadUrl,
    required this.language,
    required this.chapterCount,
  });

  factory CatalogBookDetailModel.fromJson(Map<String, dynamic> json) {
    return CatalogBookDetailModel(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String,
      coverUrl: json['cover_url'] as String,
      downloadUrl: json['download_url'] as String,
      language: json['language'] as String,
      chapterCount: json['chapter_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'cover_url': coverUrl,
      'download_url': downloadUrl,
      'language': language,
      'chapter_count': chapterCount,
    };
  }

  CatalogBookDetail toEntity() {
    return CatalogBookDetail(
      id: id,
      title: title,
      author: author,
      description: description,
      coverUrl: coverUrl,
      downloadUrl: downloadUrl,
      language: language,
      chapterCount: chapterCount,
    );
  }
}
