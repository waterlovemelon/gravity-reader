import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:xml/xml.dart';

typedef ImageDimensionLookup = Map<String, ({double width, double height})>;

class XhtmlDocumentParser {
  const XhtmlDocumentParser();

  ChapterDocument parse({
    required int spineIndex,
    required String chapterId,
    required String chapterHref,
    required String fallbackTitle,
    required String xhtml,
    required ImageDimensionLookup imageDimensions,
  }) {
    final document = XmlDocument.parse(xhtml);
    final body = document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'body',
    );

    final blocks = <BlockNode>[];
    for (final child in body.children) {
      blocks.addAll(
        _parseBlockNode(
          node: child,
          chapterHref: chapterHref,
          imageDimensions: imageDimensions,
        ),
      );
    }

    final title = blocks
        .where((block) => block.type == BlockNodeType.heading)
        .map(_flattenInlineText)
        .firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => fallbackTitle,
        );

    return ChapterDocument(
      spineIndex: spineIndex,
      id: chapterId,
      href: chapterHref,
      title: title,
      blocks: List<BlockNode>.unmodifiable(blocks),
    );
  }

  List<BlockNode> _parseBlockNode({
    required XmlNode node,
    required String chapterHref,
    required ImageDimensionLookup imageDimensions,
  }) {
    if (node is XmlText) {
      final value = _normalizeText(node.value);
      if (value.isEmpty) {
        return const [];
      }
      return [
        BlockNode.paragraph(children: [InlineNode.text(value)]),
      ];
    }

    if (node is! XmlElement) {
      return const [];
    }

    switch (node.name.local) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return [
          BlockNode.heading(
            level: int.parse(node.name.local.substring(1)),
            children: _parseInlineNodes(node),
          ),
        ];
      case 'p':
        return [BlockNode.paragraph(children: _parseInlineNodes(node))];
      case 'blockquote':
        return [BlockNode.quote(children: _parseInlineNodes(node))];
      case 'hr':
        return const [BlockNode.separator()];
      case 'img':
        final source = node.getAttribute('src');
        if (source == null || source.isEmpty) {
          return const [];
        }
        final resolvedSrc = EpubArchiveService().resolvePath(
          basePath: chapterHref,
          relativePath: source,
        );
        final dimensions = imageDimensions[resolvedSrc];
        return [
          BlockNode.image(
            src: resolvedSrc,
            alt: node.getAttribute('alt'),
            intrinsicWidth: dimensions?.width,
            intrinsicHeight: dimensions?.height,
          ),
        ];
      case 'body':
      case 'section':
      case 'article':
      case 'div':
        return node.children
            .expand(
              (child) => _parseBlockNode(
                node: child,
                chapterHref: chapterHref,
                imageDimensions: imageDimensions,
              ),
            )
            .toList(growable: false);
      default:
        final inlineChildren = _parseInlineNodes(node);
        if (inlineChildren.isEmpty) {
          return const [];
        }
        return [BlockNode.paragraph(children: inlineChildren)];
    }
  }

  List<InlineNode> _parseInlineNodes(XmlNode node) {
    final children = <InlineNode>[];
    for (final child in node.children) {
      if (child is XmlText) {
        final value = _normalizeText(child.value);
        if (value.isNotEmpty) {
          children.add(InlineNode.text(value));
        }
        continue;
      }
      if (child is! XmlElement) {
        continue;
      }

      final nested = _parseInlineNodes(child);
      switch (child.name.local) {
        case 'strong':
        case 'b':
          if (nested.isNotEmpty) {
            children.add(InlineNode.bold(children: nested));
          }
          break;
        case 'em':
        case 'i':
          if (nested.isNotEmpty) {
            children.add(InlineNode.italic(children: nested));
          }
          break;
        case 'a':
          children.add(
            InlineNode.link(
              href: child.getAttribute('href') ?? '',
              children: nested,
            ),
          );
          break;
        case 'span':
          if (nested.isNotEmpty) {
            children.add(
              InlineNode.styledSpan(
                styles: _parseStyleMap(child.getAttribute('style')),
                children: nested,
              ),
            );
          }
          break;
        case 'br':
          children.add(const InlineNode.text('\n'));
          break;
        default:
          children.addAll(nested);
      }
    }
    return children;
  }

  Map<String, String> _parseStyleMap(String? style) {
    if (style == null || style.trim().isEmpty) {
      return const {};
    }
    final resolved = <String, String>{};
    for (final part in style.split(';')) {
      if (!part.contains(':')) {
        continue;
      }
      final pieces = part.split(':');
      resolved[pieces.first.trim()] = pieces.sublist(1).join(':').trim();
    }
    return resolved;
  }

  String _flattenInlineText(BlockNode block) {
    return block.children.map(_flattenInlineNodeText).join();
  }

  String _flattenInlineNodeText(InlineNode node) {
    if (node.type == InlineNodeType.text) {
      return node.text;
    }
    return node.children.map(_flattenInlineNodeText).join();
  }

  String _normalizeText(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
