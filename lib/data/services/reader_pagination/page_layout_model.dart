enum PageSegmentType { heading, paragraph, quote, separator, image }

class PageSegment {
  final int blockIndex;
  final int startInlineOffset;
  final int endInlineOffset;
  final PageSegmentType segmentType;
  final double leadingSpacingBefore;
  final double measuredHeight;

  const PageSegment({
    required this.blockIndex,
    required this.startInlineOffset,
    required this.endInlineOffset,
    required this.segmentType,
    this.leadingSpacingBefore = 0,
    this.measuredHeight = 0,
  });

  factory PageSegment.fromJson(Map<String, dynamic> json) {
    return PageSegment(
      blockIndex: json['blockIndex'] as int,
      startInlineOffset: json['startInlineOffset'] as int,
      endInlineOffset: json['endInlineOffset'] as int,
      segmentType: PageSegmentType.values.byName(json['segmentType'] as String),
      leadingSpacingBefore: ((json['leadingSpacingBefore'] as num?) ?? 0)
          .toDouble(),
      measuredHeight: ((json['measuredHeight'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockIndex': blockIndex,
      'startInlineOffset': startInlineOffset,
      'endInlineOffset': endInlineOffset,
      'segmentType': segmentType.name,
      'leadingSpacingBefore': leadingSpacingBefore,
      'measuredHeight': measuredHeight,
    };
  }
}

class PageLayout {
  final int pageIndex;
  final int chapterIndex;
  final List<PageSegment> segments;
  final double lineHeightAdjustment;

  const PageLayout({
    required this.pageIndex,
    required this.chapterIndex,
    required this.segments,
    this.lineHeightAdjustment = 0,
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
      lineHeightAdjustment: ((json['lineHeightAdjustment'] as num?) ?? 0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pageIndex': pageIndex,
      'chapterIndex': chapterIndex,
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'lineHeightAdjustment': lineHeightAdjustment,
    };
  }
}

class PaginatedChapter {
  final String chapterId;
  final List<PageLayout> pages;

  const PaginatedChapter({required this.chapterId, required this.pages});
}
