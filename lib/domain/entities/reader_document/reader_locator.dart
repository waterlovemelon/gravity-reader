import 'dart:convert';

enum ReaderLocatorBias { leading, trailing }

class ReaderLocator {
  final int spineIndex;
  final int blockIndex;
  final int inlineOffset;
  final ReaderLocatorBias bias;

  const ReaderLocator({
    required this.spineIndex,
    required this.blockIndex,
    required this.inlineOffset,
    required this.bias,
  });

  factory ReaderLocator.fromJson(Map<String, dynamic> json) {
    return ReaderLocator(
      spineIndex: json['spineIndex'] as int,
      blockIndex: json['blockIndex'] as int,
      inlineOffset: json['inlineOffset'] as int,
      bias: ReaderLocatorBias.values.byName(json['bias'] as String),
    );
  }

  factory ReaderLocator.decode(String value) {
    return ReaderLocator.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() {
    return {
      'spineIndex': spineIndex,
      'blockIndex': blockIndex,
      'inlineOffset': inlineOffset,
      'bias': bias.name,
    };
  }

  String encode() => jsonEncode(toJson());
}
