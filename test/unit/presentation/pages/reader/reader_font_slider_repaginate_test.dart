import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('font size slider repaginates only after drag ends', () {
    final source = File(
      'lib/presentation/pages/reader/reader_page.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    final smallScaleMarkStart = source.indexOf(
      "_buildScaleMark(\n                                                label: 'A',\n                                                small: true,",
    );
    expect(smallScaleMarkStart, isNonNegative);

    final sliderEnd = source.indexOf(
      '_buildScaleMark(\n                                                label: \'A\',\n                                                small: false,',
      smallScaleMarkStart,
    );
    expect(sliderEnd, isNonNegative);

    final fontSliderSource = source.substring(smallScaleMarkStart, sliderEnd);

    expect(fontSliderSource, contains('value: fontSize.toDouble()'));
    expect(fontSliderSource, contains('onChangeEnd:'));
    expect(fontSliderSource, contains('_scheduleRepaginate();'));

    final onChangedStart = fontSliderSource.indexOf('onChanged:');
    final onChangedEnd = fontSliderSource.indexOf('onChangeEnd:');
    expect(onChangedStart, isNonNegative);
    expect(onChangedEnd, isNonNegative);

    final onChangedSource = fontSliderSource.substring(
      onChangedStart,
      onChangedEnd,
    );
    expect(onChangedSource, isNot(contains('_scheduleRepaginate();')));
    expect(onChangedSource, isNot(contains('_fontSizePreset =')));
  });
}
