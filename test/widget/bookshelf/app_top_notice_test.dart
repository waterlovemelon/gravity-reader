import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/core/constants/theme_constants.dart';
import 'package:myreader/presentation/widgets/app_top_notice.dart';

void main() {
  test('top notice duration is brief', () {
    expect(AppTopNotice.visibleDuration, const Duration(milliseconds: 1600));
  });

  testWidgets('top notice renders compact message and dismisses on tap', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTopNotice(
            message: '已导入《测试书籍》',
            theme: ThemeConstants.greenTheme,
            kind: AppTopNoticeKind.success,
            animation: const AlwaysStoppedAnimation<double>(1),
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('已导入《测试书籍》'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    final noticeSize = tester.getSize(find.byType(AppTopNotice));
    expect(noticeSize.height, lessThanOrEqualTo(58));

    await tester.tap(find.text('已导入《测试书籍》'));
    expect(dismissed, isTrue);
  });
}
