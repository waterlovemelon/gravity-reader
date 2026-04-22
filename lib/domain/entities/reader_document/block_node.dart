import 'package:myreader/domain/entities/reader_document/inline_node.dart';

enum BlockNodeType { heading, paragraph, quote, separator, image }

class BlockNode {
  final BlockNodeType type;
  final int? level;
  final List<InlineNode> children;
  final String? src;
  final String? alt;
  final double? intrinsicWidth;
  final double? intrinsicHeight;
  final Map<String, String> styles;

  const BlockNode({
    required this.type,
    this.level,
    this.children = const [],
    this.src,
    this.alt,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.styles = const {},
  });

  const BlockNode.heading({
    required int level,
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(
         type: BlockNodeType.heading,
         level: level,
         children: children,
         styles: styles,
       );

  const BlockNode.paragraph({
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(type: BlockNodeType.paragraph, children: children, styles: styles);

  const BlockNode.quote({
    required List<InlineNode> children,
    Map<String, String> styles = const {},
  }) : this(type: BlockNodeType.quote, children: children, styles: styles);

  const BlockNode.separator() : this(type: BlockNodeType.separator);

  const BlockNode.image({
    required String src,
    String? alt,
    double? intrinsicWidth,
    double? intrinsicHeight,
  }) : this(
         type: BlockNodeType.image,
         src: src,
         alt: alt,
         intrinsicWidth: intrinsicWidth,
         intrinsicHeight: intrinsicHeight,
       );

  factory BlockNode.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>? ?? const [];
    return BlockNode(
      type: BlockNodeType.values.byName(json['type'] as String),
      level: json['level'] as int?,
      children: childrenJson
          .cast<Map<String, dynamic>>()
          .map(InlineNode.fromJson)
          .toList(growable: false),
      src: json['src'] as String?,
      alt: json['alt'] as String?,
      intrinsicWidth: (json['intrinsicWidth'] as num?)?.toDouble(),
      intrinsicHeight: (json['intrinsicHeight'] as num?)?.toDouble(),
      styles: Map<String, String>.from(
        json['styles'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'level': level,
      'children': children.map((child) => child.toJson()).toList(),
      'src': src,
      'alt': alt,
      'intrinsicWidth': intrinsicWidth,
      'intrinsicHeight': intrinsicHeight,
      'styles': styles,
    };
  }
}
