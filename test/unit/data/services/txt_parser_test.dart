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

    test('prefers dominant chinese marker when mixed heading styles exist', () {
      const content = '''
第1章 起始
第一章正文。

第2章 深入
第二章正文。

第3章 转折
第三章正文。

第1节 杂项说明
这行不应被切成新章节。
''';

      final result = parser.parse(content);

      expect(result.chapters.length, 3);
      expect(result.chapters[0].title, '第1章 起始');
      expect(result.chapters[1].title, '第2章 深入');
      expect(result.chapters[2].title, '第3章 转折');
      expect(result.chapters[2].content, contains('第1节 杂项说明'));
    });
  });
}
