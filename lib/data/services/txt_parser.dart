import 'dart:math';

class TxtChapter {
  final String id;
  final String title;
  final String content;
  final int index;

  const TxtChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.index,
  });
}

class TxtParseResult {
  final List<TxtChapter> chapters;

  const TxtParseResult({required this.chapters});
}

class TxtParser {
  static final RegExp _cnChapterPattern = RegExp(
    r'^\s*第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[章节卷部篇回集]\s*$|'
    r'^\s*第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[章节卷部篇回集](?:\s+|[:：·.-]\s*)[\S ]{1,30}$',
  );
  static final RegExp _cnVolumePattern = RegExp(
    r'^\s*[卷部册]\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[\S ]{0,24}$',
  );
  static final RegExp _cnSpecialHeadingPattern = RegExp(
    r'^\s*(序章|楔子|前言|引子|后记|尾声|终章|番外)([\s:：-].{0,24})?\s*$',
  );
  static final RegExp _enChapterPattern = RegExp(
    r'^\s*(chapter|part|section)\s+[0-9ivxlcdm]+([\s:：.-].*)?$',
    caseSensitive: false,
  );
  static final RegExp _enSpecialHeadingPattern = RegExp(
    r'^\s*(prologue|epilogue|preface|introduction)\s*$',
    caseSensitive: false,
  );

  TxtParseResult parse(String rawText, {int chunkSize = 3000}) {
    final normalizedText = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalizedText.isEmpty) {
      return const TxtParseResult(chapters: []);
    }

    final lines = normalizedText.split('\n');
    final headingIndexes = <int>[];

    for (var i = 0; i < lines.length; i++) {
      if (_isChapterHeading(lines[i])) {
        headingIndexes.add(i);
      }
    }

    if (headingIndexes.isEmpty) {
      return TxtParseResult(
        chapters: _splitByLength(normalizedText, chunkSize),
      );
    }

    final chapters = <TxtChapter>[];

    if (headingIndexes.first > 0) {
      final preface = lines.take(headingIndexes.first).join('\n').trim();
      if (preface.isNotEmpty) {
        chapters.add(
          TxtChapter(
            id: 'txt_preface',
            title: '前言',
            content: preface,
            index: chapters.length,
          ),
        );
      }
    }

    for (var i = 0; i < headingIndexes.length; i++) {
      final start = headingIndexes[i];
      final end = i + 1 < headingIndexes.length
          ? headingIndexes[i + 1]
          : lines.length;
      final segment = lines.sublist(start, end).join('\n').trim();
      if (segment.isEmpty) {
        continue;
      }

      final title = lines[start].trim();
      chapters.add(
        TxtChapter(
          id: 'txt_${chapters.length + 1}',
          title: title,
          content: segment,
          index: chapters.length,
        ),
      );
    }

    if (chapters.isEmpty) {
      return TxtParseResult(
        chapters: _splitByLength(normalizedText, chunkSize),
      );
    }

    return TxtParseResult(chapters: chapters);
  }

  bool _isChapterHeading(String line) {
    final text = line.trim();
    if (text.isEmpty || text.length > 40) {
      return false;
    }

    return _cnChapterPattern.hasMatch(text) ||
        _cnVolumePattern.hasMatch(text) ||
        _cnSpecialHeadingPattern.hasMatch(text) ||
        _enChapterPattern.hasMatch(text) ||
        _enSpecialHeadingPattern.hasMatch(text);
  }

  List<TxtChapter> _splitByLength(String text, int chunkSize) {
    final safeChunkSize = max(1000, chunkSize);
    final chapters = <TxtChapter>[];
    var cursor = 0;

    while (cursor < text.length) {
      var end = min(cursor + safeChunkSize, text.length);
      if (end < text.length) {
        final boundary = text.lastIndexOf('\n', end);
        if (boundary > cursor + safeChunkSize ~/ 3) {
          end = boundary;
        }
      }

      final chunk = text.substring(cursor, end).trim();
      if (chunk.isNotEmpty) {
        final index = chapters.length;
        chapters.add(
          TxtChapter(
            id: 'txt_${index + 1}',
            title: '第${index + 1}节',
            content: chunk,
            index: index,
          ),
        );
      }

      cursor = end;
    }

    return chapters;
  }
}
