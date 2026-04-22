class PaginationSettings {
  final double viewportWidth;
  final double viewportHeight;
  final double contentPaddingTop;
  final double contentPaddingBottom;
  final double contentPaddingHorizontal;
  final double fontSize;
  final double lineHeight;

  const PaginationSettings({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentPaddingTop,
    required this.contentPaddingBottom,
    required this.contentPaddingHorizontal,
    required this.fontSize,
    required this.lineHeight,
  });

  double get contentHeight =>
      viewportHeight - contentPaddingTop - contentPaddingBottom;
}
