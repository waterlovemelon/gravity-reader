import 'package:myreader/domain/entities/remote_catalog/catalog_manifest.dart';

class CatalogManifestModel {
  final String bookId;
  final String version;
  final String title;
  final String author;
  final List<CatalogManifestChapterModel> chapters;

  const CatalogManifestModel({
    required this.bookId,
    required this.version,
    required this.title,
    required this.author,
    required this.chapters,
  });

  factory CatalogManifestModel.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List<dynamic>;
    return CatalogManifestModel(
      bookId: json['book_id'] as String,
      version: json['version'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      chapters: chaptersJson
          .cast<Map<String, dynamic>>()
          .map(CatalogManifestChapterModel.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'version': version,
      'title': title,
      'author': author,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }

  CatalogManifest toEntity() {
    return CatalogManifest(
      bookId: bookId,
      version: version,
      title: title,
      author: author,
      chapters: chapters.map((chapter) => chapter.toEntity()).toList(),
    );
  }
}

class CatalogManifestChapterModel {
  final String id;
  final String title;
  final int order;
  final int wordCount;

  const CatalogManifestChapterModel({
    required this.id,
    required this.title,
    required this.order,
    required this.wordCount,
  });

  factory CatalogManifestChapterModel.fromJson(Map<String, dynamic> json) {
    return CatalogManifestChapterModel(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      wordCount: json['word_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'order': order, 'word_count': wordCount};
  }

  CatalogManifestChapter toEntity() {
    return CatalogManifestChapter(
      id: id,
      title: title,
      order: order,
      wordCount: wordCount,
    );
  }
}
