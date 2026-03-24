import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:myreader/data/services/txt_parser.dart';
import 'package:path_provider/path_provider.dart';

class TxtImportCacheChapter {
  final String title;
  final String content;
  final int index;
  final int globalStart;

  const TxtImportCacheChapter({
    required this.title,
    required this.content,
    required this.index,
    required this.globalStart,
  });

  factory TxtImportCacheChapter.fromJson(Map<String, dynamic> json) {
    return TxtImportCacheChapter(
      title: json['title'] as String,
      content: json['content'] as String,
      index: json['index'] as int,
      globalStart: json['globalStart'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'index': index,
      'globalStart': globalStart,
    };
  }
}

class TxtImportCacheData {
  final String encoding;
  final int totalLength;
  final List<TxtImportCacheChapter> chapters;

  const TxtImportCacheData({
    required this.encoding,
    required this.totalLength,
    required this.chapters,
  });

  factory TxtImportCacheData.fromJson(Map<String, dynamic> json) {
    final chapters = (json['chapters'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TxtImportCacheChapter.fromJson)
        .toList(growable: false);
    return TxtImportCacheData(
      encoding: json['encoding'] as String? ?? 'unknown',
      totalLength: json['totalLength'] as int? ?? 0,
      chapters: chapters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': TxtImportCacheService.cacheVersion,
      'encoding': encoding,
      'totalLength': totalLength,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }
}

Map<String, dynamic> buildTxtImportCachePayload(Map<String, dynamic> input) {
  final text = input['text'] as String? ?? '';
  final encoding = input['encoding'] as String? ?? 'unknown';
  final chapters = TxtParser().parse(text).chapters;
  final chapterData = <Map<String, dynamic>>[];
  var totalLength = 0;

  if (chapters.isEmpty) {
    const emptyContent = '该 TXT 文件为空。';
    chapterData.add({
      'title': '正文',
      'content': emptyContent,
      'index': 0,
      'globalStart': 0,
    });
    totalLength = emptyContent.length;
  } else {
    for (final chapter in chapters) {
      final body = _normalizeTxtParagraphSpacing(
        chapter.content.replaceAll('\r\n', '\n'),
      );
      if (body.isEmpty) {
        continue;
      }
      chapterData.add({
        'title': chapter.title,
        'content': body,
        'index': chapter.index,
        'globalStart': totalLength,
      });
      totalLength += body.length;
    }
    if (chapterData.isEmpty) {
      const emptyContent = '该 TXT 文件为空。';
      chapterData.add({
        'title': '正文',
        'content': emptyContent,
        'index': 0,
        'globalStart': 0,
      });
      totalLength = emptyContent.length;
    }
  }

  return {
    'version': TxtImportCacheService.cacheVersion,
    'encoding': encoding,
    'totalLength': totalLength,
    'chapters': chapterData,
  };
}

String _normalizeTxtParagraphSpacing(String text) {
  var processed = text.replaceAll(RegExp(r'\n{2,}'), '\n\n\n\n');
  processed = processed.replaceFirst(RegExp(r'^\n+'), '');
  processed = processed.replaceFirst(RegExp(r'\n+$'), '');
  return processed;
}

class TxtImportCacheService {
  static const int cacheVersion = 2;

  const TxtImportCacheService();

  Future<TxtImportCacheData> prepare({
    required String text,
    required String encoding,
  }) async {
    final payload = await compute(buildTxtImportCachePayload, {
      'text': text,
      'encoding': encoding,
    });
    return TxtImportCacheData.fromJson(payload);
  }

  Future<void> write({
    required String bookId,
    required TxtImportCacheData data,
  }) async {
    final path = await cachePath(bookId);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }

  Future<TxtImportCacheData?> read(String bookId) async {
    try {
      final path = await cachePath(bookId);
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if ((decoded['version'] as int?) != cacheVersion) {
        return null;
      }
      return TxtImportCacheData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<String> cachePath(String bookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/book_cache/$bookId/txt_structure_v$cacheVersion.json';
  }

  Future<void> delete(String bookId) async {
    try {
      final path = await cachePath(bookId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      final dir = file.parent;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore cache cleanup failures during book deletion.
    }
  }
}
