enum PageSegmentType { heading, paragraph, quote, separator, image }

class PageSegment {
  final int blockIndex;
  final int startInlineOffset;
  final int endInlineOffset;
  final PageSegmentType segmentType;

  const PageSegment({
    required this.blockIndex,
    required this.startInlineOffset,
    required this.endInlineOffset,
    required this.segmentType,
  });

  factory PageSegment.fromJson(Map<String, dynamic> json) {
    return PageSegment(
      blockIndex: json['blockIndex'] as int,
      startInlineOffset: json['startInlineOffset'] as int,
      endInlineOffset: json['endInlineOffset'] as int,
      segmentType: PageSegmentType.values.byName(json['segmentType'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockIndex': blockIndex,
      'startInlineOffset': startInlineOffset,
      'endInlineOffset': endInlineOffset,
      'segmentType': segmentType.name,
    };
  }
}

class PageLayout {
  final int pageIndex;
  final int chapterIndex;
  final List<PageSegment> segments;

  const PageLayout({
    required this.pageIndex,
    required this.chapterIndex,
    required this.segments,
  });

  factory PageLayout.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List<dynamic>? ?? const [];
    return PageLayout(
      pageIndex: json['pageIndex'] as int,
      chapterIndex: json['chapterIndex'] as int,
      segments: segmentsJson
          .cast<Map<String, dynamic>>()
          .map(PageSegment.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageIndex': pageIndex,
      'chapterIndex': chapterIndex,
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }
}

class PaginatedChapter {
  final String chapterId;
  final List<PageLayout> pages;

  const PaginatedChapter({required this.chapterId, required this.pages});
}
