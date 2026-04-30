import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookshelfPage supports repeated top notice animation controllers', () {
    final source = File(
      'lib/presentation/pages/bookshelf/bookshelf_page.dart',
    ).readAsStringSync();

    expect(source, contains('with TickerProviderStateMixin'));
    expect(source, isNot(contains('with SingleTickerProviderStateMixin')));
  });
}
