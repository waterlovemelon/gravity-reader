import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:myreader/domain/entities/book.dart';

class Chapter {
  final String id;
  final String title;
  final String href;
  final int index;

  Chapter({
    required this.id,
    required this.title,
    required this.href,
    required this.index,
  });
}

class BookMetadata {
  final String? title;
  final String? author;
  final String? description;
  final String? publisher;
  final String? language;
  final String? isbn;
  final List<String> subjects;
  final String? coverPath;

  BookMetadata({
    this.title,
    this.author,
    this.description,
    this.publisher,
    this.language,
    this.isbn,
    this.subjects = const [],
    this.coverPath,
  });
}

class EpubParseResult {
  final BookMetadata metadata;
  final List<Chapter> chapters;
  final int totalPages;
  final String? error;

  EpubParseResult({
    required this.metadata,
    required this.chapters,
    required this.totalPages,
    this.error,
  });

  bool get hasError => error != null;
}

abstract class EpubParser {
  Future<EpubParseResult> parse(String epubPath);
  Future<String?> extractCover(String epubPath, String destinationPath);
}

class EpubParserImpl implements EpubParser {
  @override
  Future<EpubParseResult> parse(String epubPath) async {
    try {
      final file = File(epubPath);
      if (!await file.exists()) {
        return EpubParseResult(
          metadata: BookMetadata(),
          chapters: [],
          totalPages: 0,
          error: 'File not found: $epubPath',
        );
      }

      final appDir = await getApplicationDocumentsDirectory();
      final extractPath =
          '${appDir.path}/epub_extracted/${DateTime.now().millisecondsSinceEpoch}';
      await Directory(extractPath).create(recursive: true);

      final metadata = await _extractMetadata(epubPath);
      final chapters = await _extractChapters(epubPath, extractPath);
      final totalPages = chapters.length;

      return EpubParseResult(
        metadata: metadata,
        chapters: chapters,
        totalPages: totalPages,
      );
    } catch (e) {
      return EpubParseResult(
        metadata: BookMetadata(),
        chapters: [],
        totalPages: 0,
        error: 'Failed to parse EPUB: $e',
      );
    }
  }

  Future<BookMetadata> _extractMetadata(String epubPath) async {
    return BookMetadata(
      title: 'Unknown Title',
      author: 'Unknown Author',
      subjects: [],
    );
  }

  Future<List<Chapter>> _extractChapters(
    String epubPath,
    String extractPath,
  ) async {
    final chapters = <Chapter>[];

    chapters.add(
      Chapter(
        id: 'chapter_1',
        title: 'Chapter 1',
        href: 'chapter1.xhtml',
        index: 0,
      ),
    );

    for (int i = 2; i <= 10; i++) {
      chapters.add(
        Chapter(
          id: 'chapter_$i',
          title: 'Chapter $i',
          href: 'chapter$i.xhtml',
          index: i - 1,
        ),
      );
    }

    return chapters;
  }

  @override
  Future<String?> extractCover(String epubPath, String destinationPath) async {
    try {
      return null;
    } catch (e) {
      return null;
    }
  }
}

class BookImporter {
  final EpubParser _parser;

  BookImporter(this._parser);

  Future<Book?> importBook(String epubPath) async {
    final result = await _parser.parse(epubPath);

    if (result.hasError) {
      return null;
    }

    final file = File(epubPath);
    final fileSize = await file.length();

    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: result.metadata.title ?? 'Untitled',
      author: result.metadata.author,
      coverPath: result.metadata.coverPath,
      epubPath: epubPath,
      totalPages: result.totalPages,
      fileSize: fileSize,
      importedAt: DateTime.now(),
    );

    return book;
  }
}
