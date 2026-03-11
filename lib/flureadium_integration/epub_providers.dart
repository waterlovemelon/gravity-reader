import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/flureadium_integration/epub_parser.dart';

final epubParserProvider = Provider<EpubParser>((ref) {
  return EpubParserImpl();
});

final bookImporterProvider = Provider<BookImporter>((ref) {
  final parser = ref.watch(epubParserProvider);
  return BookImporter(parser);
});

final epubParseResultProvider = FutureProvider.family<EpubParseResult, String>((
  ref,
  epubPath,
) async {
  final parser = ref.watch(epubParserProvider);
  return await parser.parse(epubPath);
});
