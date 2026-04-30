import 'package:myreader/domain/entities/reader_document/block_node.dart';

class ChapterDocument {
  final int spineIndex;
  final String id;
  final String href;
  final String title;
  final List<BlockNode> blocks;

  const ChapterDocument({
    required this.spineIndex,
    required this.id,
    required this.href,
    required this.title,
    required this.blocks,
  });

  factory ChapterDocument.fromJson(Map<String, dynamic> json) {
    final blocksJson = json['blocks'] as List<dynamic>? ?? const [];
    return ChapterDocument(
      spineIndex: json['spineIndex'] as int,
      id: json['id'] as String,
      href: json['href'] as String,
      title: json['title'] as String? ?? '',
      blocks: blocksJson
          .cast<Map<String, dynamic>>()
          .map(BlockNode.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spineIndex': spineIndex,
      'id': id,
      'href': href,
      'title': title,
      'blocks': blocks.map((block) => block.toJson()).toList(),
    };
  }
}
