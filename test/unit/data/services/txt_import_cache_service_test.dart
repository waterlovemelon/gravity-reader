import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/services/txt_import_cache_service.dart';

void main() {
  group('buildTxtImportCachePayload', () {
    test('builds chapter cache with global offsets', () {
      final payload = buildTxtImportCachePayload({
        'text': '''
第一章 初见
第一章正文。

第二章 再见
第二章正文。
''',
        'encoding': 'utf8',
      });

      final data = TxtImportCacheData.fromJson(payload);

      expect(data.encoding, 'utf8');
      expect(data.chapters.length, 2);
      expect(data.chapters[0].title, '第一章 初见');
      expect(data.chapters[0].globalStart, 0);
      expect(data.chapters[1].globalStart, data.chapters[0].content.length);
      expect(
        data.totalLength,
        data.chapters[0].content.length + data.chapters[1].content.length,
      );
    });
  });
}
