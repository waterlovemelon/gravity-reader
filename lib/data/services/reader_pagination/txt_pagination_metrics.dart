import 'dart:math';

class TxtPaginationMetrics {
  static const double minimumBodyHeight = 48;

  const TxtPaginationMetrics._();

  static double bodyHeight({
    required double viewportHeight,
    required double viewPaddingTop,
    required double viewPaddingBottom,
    required double contentPaddingVertical,
    required double pageChromeHeight,
    required double paginationSafetyInset,
  }) {
    final baseContentHeight =
        viewportHeight -
        viewPaddingTop -
        viewPaddingBottom -
        contentPaddingVertical;
    return bodyHeightFromBase(
      baseContentHeight: baseContentHeight,
      pageChromeHeight: pageChromeHeight,
      paginationSafetyInset: paginationSafetyInset,
    );
  }

  static double bodyHeightFromBase({
    required double baseContentHeight,
    required double pageChromeHeight,
    required double paginationSafetyInset,
  }) {
    return max(
      minimumBodyHeight,
      baseContentHeight - pageChromeHeight - paginationSafetyInset,
    );
  }
}
