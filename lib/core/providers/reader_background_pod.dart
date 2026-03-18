import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_background_provider.dart';

/// 阅读器背景 Provider（Riverpod 包装）
final readerBackgroundProvider = ChangeNotifierProvider<ReaderBackgroundProvider>((ref) {
  return ReaderBackgroundProvider();
});
