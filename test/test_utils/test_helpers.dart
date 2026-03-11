import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(MaterialApp(home: widget));
  await tester.pumpAndSettle();
}

void expectWidgetExists(Type widgetType) {
  expect(find.byType(widgetType), findsOneWidget);
}

void expectWidgetsExist(List<Type> widgetTypes) {
  for (final type in widgetTypes) {
    expect(find.byType(type), findsOneWidget);
  }
}

void expectTextExists(String text) {
  expect(find.text(text), findsOneWidget);
}

void expectTextExistsMultiple(String text, int count) {
  expect(find.text(text), findsNWidgets(count));
}
