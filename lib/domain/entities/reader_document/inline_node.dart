enum InlineNodeType { text, bold, italic, link, styledSpan }

class InlineNode {
  final InlineNodeType type;
  final String text;
  final String? href;
  final Map<String, String> styles;
  final List<InlineNode> children;

  const InlineNode({
    required this.type,
    this.text = '',
    this.href,
    this.styles = const {},
    this.children = const [],
  });

  const InlineNode.text(String value)
    : type = InlineNodeType.text,
      text = value,
      href = null,
      styles = const {},
      children = const [];

  const InlineNode.bold({required List<InlineNode> children})
    : type = InlineNodeType.bold,
      text = '',
      href = null,
      styles = const {},
      children = children;

  const InlineNode.italic({required List<InlineNode> children})
    : type = InlineNodeType.italic,
      text = '',
      href = null,
      styles = const {},
      children = children;

  const InlineNode.link({
    required String href,
    required List<InlineNode> children,
  }) : type = InlineNodeType.link,
       text = '',
       href = href,
       styles = const {},
       children = children;

  const InlineNode.styledSpan({
    required Map<String, String> styles,
    required List<InlineNode> children,
  }) : type = InlineNodeType.styledSpan,
       text = '',
       href = null,
       styles = styles,
       children = children;

  factory InlineNode.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>? ?? const [];
    return InlineNode(
      type: InlineNodeType.values.byName(json['type'] as String),
      text: json['text'] as String? ?? '',
      href: json['href'] as String?,
      styles: Map<String, String>.from(
        json['styles'] as Map<String, dynamic>? ?? const {},
      ),
      children: childrenJson
          .cast<Map<String, dynamic>>()
          .map(InlineNode.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'href': href,
      'styles': styles,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }
}
