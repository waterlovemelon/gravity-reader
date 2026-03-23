import 'dart:math';

class TxtChapter {
  final String id;
  final String title;
  final String content;
  final int index;
  final bool isVolume;

  const TxtChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.index,
    this.isVolume = false,
  });
}

class TxtParseResult {
  final List<TxtChapter> chapters;

  const TxtParseResult({required this.chapters});
}

class TxtParser {
  // 章节标记：章、节、回（古典小说）、集
  static final RegExp _cnChapterPattern = RegExp(
    r'^\s*第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[章节回集]\s*$|'
    r'^\s*第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[章节回集](?:\s+|[:：·.-]\s*)[\S ]{1,30}$',
  );
  // 卷/部/篇作为独立模式（层级更高的分组）
  static final RegExp _cnVolumePattern = RegExp(
    r'^\s*(?:第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[卷部篇]|[卷部册篇]\s*[0-9零一二三四五六七八九十百千万〇两]+)\s*(?:[\s:：·.-]\s*[\S ]{0,24})?\s*$',
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

  // 检测主导的章节标记类型
  static final RegExp _markerPattern = RegExp(
    r'第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*([章节卷部篇回集])',
  );

  /// 检测文本中主导的章节标记类型
  /// 返回出现频率最高的标记字符（章/节/回/集），如果没有则返回 null
  String? _detectDominantMarker(String text) {
    final markerCounts = <String, int>{};

    final matches = _markerPattern.allMatches(text);
    for (final match in matches) {
      final marker = match.group(1)!;
      markerCounts[marker] = (markerCounts[marker] ?? 0) + 1;
    }

    if (markerCounts.isEmpty) {
      return null;
    }

    // 返回出现次数最多的标记
    final sorted = markerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dominant = sorted.first;
    // 如果主导标记占比超过 60%，则使用它
    final total = markerCounts.values.fold(0, (sum, count) => sum + count);
    if (dominant.value / total >= 0.6) {
      return dominant.key;
    }

    // 没有明显主导标记时返回 null，使用默认模式
    return null;
  }

  /// 根据主导标记创建对应的正则表达式
  RegExp _buildChapterPattern(String marker) {
    return RegExp(
      '^\\s*第\\s*[0-9零一二三四五六七八九十百千万〇两]+\\s*$marker\\s*\$|'
      '^\\s*第\\s*[0-9零一二三四五六七八九十百千万〇两]+\\s*$marker(?:\\s+|[:：·.-]\\s*)[\\S ]{1,30}\$',
    );
  }

  TxtParseResult parse(String rawText, {int chunkSize = 3000}) {
    final normalizedText = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalizedText.isEmpty) {
      return const TxtParseResult(chapters: []);
    }

    // 检测主导的章节标记类型
    final dominantMarker = _detectDominantMarker(normalizedText);
    final chapterPattern = dominantMarker != null
        ? _buildChapterPattern(dominantMarker)
        : _cnChapterPattern;

    final headingOffsets = <int>[];
    var lineStart = 0;
    while (lineStart < normalizedText.length) {
      final lineEnd = normalizedText.indexOf('\n', lineStart);
      final safeLineEnd = lineEnd == -1 ? normalizedText.length : lineEnd;
      final line = normalizedText.substring(lineStart, safeLineEnd);
      if (_isChapterHeading(line, chapterPattern: chapterPattern)) {
        headingOffsets.add(lineStart);
      }
      if (lineEnd == -1) {
        break;
      }
      lineStart = lineEnd + 1;
    }

    if (headingOffsets.isEmpty) {
      return TxtParseResult(
        chapters: _splitByLength(normalizedText, chunkSize),
      );
    }

    final chapters = <TxtChapter>[];

    if (headingOffsets.first > 0) {
      final preface = normalizedText.substring(0, headingOffsets.first).trim();
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

    for (var i = 0; i < headingOffsets.length; i++) {
      final start = headingOffsets[i];
      final end = i + 1 < headingOffsets.length
          ? headingOffsets[i + 1]
          : normalizedText.length;
      final segment = normalizedText.substring(start, end).trim();
      if (segment.isEmpty) {
        continue;
      }

      final lineEnd = normalizedText.indexOf('\n', start);
      final titleEnd = lineEnd == -1 || lineEnd > end ? end : lineEnd;
      final title = normalizedText.substring(start, titleEnd).trim();
      final isVolume = _isVolumeHeading(title);
      chapters.add(
        TxtChapter(
          id: 'txt_${chapters.length + 1}',
          title: title,
          content: segment,
          index: chapters.length,
          isVolume: isVolume,
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

  bool _isChapterHeading(String line, {required RegExp chapterPattern}) {
    final text = line.trim();
    if (text.isEmpty || text.length > 40) {
      return false;
    }

    return chapterPattern.hasMatch(text) ||
        _cnVolumePattern.hasMatch(text) ||
        _cnSpecialHeadingPattern.hasMatch(text) ||
        _enChapterPattern.hasMatch(text) ||
        _enSpecialHeadingPattern.hasMatch(text);
  }

  bool _isVolumeHeading(String line) {
    final text = line.trim();
    return _cnVolumePattern.hasMatch(text);
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
