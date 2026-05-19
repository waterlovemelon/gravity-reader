import 'dart:math';

class PaginationSettings {
  final double viewportWidth;
  final double viewportHeight;
  final double contentPaddingTop;
  final double contentPaddingBottom;
  final double contentPaddingHorizontal;
  final double fontSize;
  final double lineHeight;
  final double chapterStartPageChromeHeight;
  final double continuationPageChromeHeight;

  const PaginationSettings({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentPaddingTop,
    required this.contentPaddingBottom,
    required this.contentPaddingHorizontal,
    required this.fontSize,
    required this.lineHeight,
    this.chapterStartPageChromeHeight = 0,
    this.continuationPageChromeHeight = 0,
  });

  double get contentHeight =>
      viewportHeight - contentPaddingTop - contentPaddingBottom;

  double contentHeightForPage({
    required bool hasChapterTitle,
    required bool isChapterStart,
  }) {
    if (!hasChapterTitle) {
      return contentHeight;
    }
    final chromeHeight = isChapterStart
        ? chapterStartPageChromeHeight
        : continuationPageChromeHeight;
    return max(0, contentHeight - chromeHeight);
  }
}
