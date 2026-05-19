import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/reader_pagination/txt_pagination_metrics.dart';

void main() {
  test('first chapter page does not reserve continuation overlay height', () {
    final bodyHeight = TxtPaginationMetrics.bodyHeight(
      viewportHeight: 844,
      viewPaddingTop: 47,
      viewPaddingBottom: 34,
      contentPaddingVertical: 72,
      pageChromeHeight: 58,
      paginationSafetyInset: 5,
    );

    expect(bodyHeight, 628);
  });

  test('continuation page reserves only the chapter overlay height', () {
    final bodyHeight = TxtPaginationMetrics.bodyHeight(
      viewportHeight: 844,
      viewPaddingTop: 47,
      viewPaddingBottom: 34,
      contentPaddingVertical: 72,
      pageChromeHeight: 18,
      paginationSafetyInset: 5,
    );

    expect(bodyHeight, 668);
  });
}
