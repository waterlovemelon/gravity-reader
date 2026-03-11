import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyReaderApp()));

    expect(find.byType(MyReaderApp), findsOneWidget);
  });
}
