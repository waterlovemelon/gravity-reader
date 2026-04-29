import 'package:myreader/domain/entities/reader_document/block_node.dart';

double epubSpacingAfter(BlockNode block, double baseFontSize) {
  switch (block.type) {
    case BlockNodeType.heading:
      return (baseFontSize * 0.65).clamp(10.0, 18.0);
    case BlockNodeType.paragraph:
      return (baseFontSize * 0.55).clamp(8.0, 16.0);
    case BlockNodeType.quote:
      return (baseFontSize * 0.7).clamp(10.0, 18.0);
    case BlockNodeType.separator:
      return (baseFontSize * 0.7).clamp(10.0, 18.0);
    case BlockNodeType.image:
      return (baseFontSize * 0.8).clamp(12.0, 20.0);
  }
}
