import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/txt_parser.dart';

void main() {
  group('TxtParser', () {
    final parser = TxtParser();

    test('splits chinese chapter headings', () {
      const content = '''
序章
这是前言。

第一章 初识
第一章正文。

第二章 再见
第二章正文。
''';

      final result = parser.parse(content);

      expect(result.chapters.length, 3);
      expect(result.chapters[0].title, '序章');
      expect(result.chapters[1].title, '第一章 初识');
      expect(result.chapters[2].title, '第二章 再见');
    });

    test('splits english chapter headings', () {
      const content = '''
Chapter 1
Text of chapter one.

Chapter 2 - Continue
Text of chapter two.
''';

      final result = parser.parse(content);

      expect(result.chapters.length, 2);
      expect(result.chapters[0].title, 'Chapter 1');
      expect(result.chapters[1].title, 'Chapter 2 - Continue');
    });

    test('falls back to chunk split without headings', () {
      final content = List.filled(8000, '文').join();

      final result = parser.parse(content, chunkSize: 3000);

      expect(result.chapters.length, greaterThanOrEqualTo(2));
      expect(result.chapters.first.title, '第1节');
    });

    test('supports more web-novel heading styles', () {
      const content = '''
楔子
楔子内容。

第1回 初见
回目正文。

卷一 长夜
卷内容。

番外
番外内容。
''';

      final result = parser.parse(content);

      expect(result.chapters.length, 4);
      expect(result.chapters[0].title, '楔子');
      expect(result.chapters[1].title, '第1回 初见');
      expect(result.chapters[2].title, '卷一 长夜');
      expect(result.chapters[3].title, '番外');
    });

    test('uses dominant marker pattern, ignores other markers in body', () {
      // 模拟一本主要使用"第x章"的书，但正文中出现了"第x回"
      const content = '''
第一章 山村少年
他回到了家乡，想起当年第一次回来时的情景。
那是第几回了？他已经记不清。

第二章 离家
正文内容。

第三章 入门
又是一回考验。
''';

      final result = parser.parse(content);

      // 应该只检测到3个章节（第X章），而不是把正文中"第x回"也当作章节
      expect(result.chapters.length, 3);
      expect(result.chapters[0].title, '第一章 山村少年');
      expect(result.chapters[1].title, '第二章 离家');
      expect(result.chapters[2].title, '第三章 入门');
    });

    test('uses dominant marker pattern for "回" style', () {
      // 模拟一本主要使用"第x回"的书
      const content = '''
第一回 风起云涌
正文内容。

第二回 龙争虎斗
又是一章精彩的内容。这一章讲述了...

第三回 尘埃落定
正文内容。
''';

      final result = parser.parse(content);

      // 应该只检测到3个章节（第X回），"一章"不应该被误判
      expect(result.chapters.length, 3);
      expect(result.chapters[0].title, '第一回 风起云涌');
      expect(result.chapters[1].title, '第二回 龙争虎斗');
      expect(result.chapters[2].title, '第三回 尘埃落定');
    });
  });
}
