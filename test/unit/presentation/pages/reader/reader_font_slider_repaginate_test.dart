import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('font size slider repaginates only after drag ends', () {
    final source = File(
      'lib/presentation/pages/reader/reader_page.dart',
    ).readAsStringSync();

    final sliderStart = source.indexOf('value: fontSize.toDouble()');
    expect(sliderStart, isNonNegative);

    final sliderEnd = source.indexOf(
      '_buildScaleMark(\n                                                label: \'A\',\n                                                small: false,',
      sliderStart,
    );
    expect(sliderEnd, isNonNegative);

    final fontSliderSource = source.substring(sliderStart, sliderEnd);

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
