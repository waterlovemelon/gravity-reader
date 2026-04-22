import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';

class BlockLayoutMeasure {
  final double consumedHeight;
  final int endInlineOffset;
  final bool fitsWholeBlock;
  final PageSegmentType segmentType;

  const BlockLayoutMeasure({
    required this.consumedHeight,
    required this.endInlineOffset,
    required this.fitsWholeBlock,
    required this.segmentType,
  });
}

abstract class LayoutMeasurer {
  const LayoutMeasurer();

  BlockLayoutMeasure measure({
    required BlockNode block,
    required PaginationSettings settings,
    required double remainingHeight,
    required int startInlineOffset,
  });
}
