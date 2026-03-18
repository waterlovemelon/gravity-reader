import 'package:flutter/material.dart';

/// 背景类型
enum BackgroundType {
  color,      // 预设颜色
  customImage, // 自定义图片
}

/// 预设背景图片配置
class PresetBackground {
  final String id;
  final String assetPath;
  final String name;
  final String description;

  const PresetBackground({
    required this.id,
    required this.assetPath,
    required this.name,
    required this.description,
  });
}

/// 阅读器背景配置
class ReaderBackground {
  final BackgroundType type;
  final int? colorIndex; // 预设颜色索引 0-4
  final String? customImagePath; // 自定义图片路径
  final String? customImageName; // 自定义图片文件名
  final double overlayOpacity; // 遮罩透明度 0.0-1.0
  final DateTime? customImageAddedAt; // 自定义图片添加时间

  const ReaderBackground({
    required this.type,
    this.colorIndex,
    this.customImagePath,
    this.customImageName,
    this.overlayOpacity = 0.35,
    this.customImageAddedAt,
  });

  /// 复制并修改部分属性
  ReaderBackground copyWith({
    BackgroundType? type,
    int? colorIndex,
    String? customImagePath,
    String? customImageName,
    double? overlayOpacity,
    DateTime? customImageAddedAt,
  }) {
    return ReaderBackground(
      type: type ?? this.type,
      colorIndex: colorIndex ?? this.colorIndex,
      customImagePath: customImagePath ?? this.customImagePath,
      customImageName: customImageName ?? this.customImageName,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      customImageAddedAt: customImageAddedAt ?? this.customImageAddedAt,
    );
  }

  /// 转换为 JSON（用于 SharedPreferences）
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'colorIndex': colorIndex,
      'customImagePath': customImagePath,
      'customImageName': customImageName,
      'overlayOpacity': overlayOpacity,
      'customImageAddedAt': customImageAddedAt?.millisecondsSinceEpoch,
    };
  }

  /// 从 JSON 解析
  factory ReaderBackground.fromJson(Map<String, dynamic> json) {
    return ReaderBackground(
      type: BackgroundType.values.asNameMap()[json['type'] as String?] ?? BackgroundType.color,
      colorIndex: json['colorIndex'] as int?,
      customImagePath: json['customImagePath'] as String?,
      customImageName: json['customImageName'] as String?,
      overlayOpacity: (json['overlayOpacity'] as num?)?.toDouble() ?? 0.35,
      customImageAddedAt: json['customImageAddedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['customImageAddedAt'] as int)
          : null,
    );
  }

  /// 默认背景（浅色）
  static const ReaderBackground defaultBackground = ReaderBackground(
    type: BackgroundType.color,
    colorIndex: 0,
  );

  /// 预设背景图片列表（5张）
  static const List<PresetBackground> presetBackgrounds = [
    PresetBackground(
      id: 'paper_texture',
      assetPath: 'assets/backgrounds/paper_texture.jpg',
      name: '纸质纹理',
      description: '温暖的纸质纹理',
    ),
    PresetBackground(
      id: 'book_page',
      assetPath: 'assets/backgrounds/book_page.jpg',
      name: '书页效果',
      description: '经典书页质感',
    ),
    PresetBackground(
      id: 'warm_beach',
      assetPath: 'assets/backgrounds/warm_beach.jpg',
      name: '温暖沙滩',
      description: '柔和的沙滩色调',
    ),
    PresetBackground(
      id: 'classic_parchment',
      assetPath: 'assets/backgrounds/classic_parchment.jpg',
      name: '经典羊皮纸',
      description: '复古羊皮纸质感',
    ),
    PresetBackground(
      id: 'subtle_grain',
      assetPath: 'assets/backgrounds/subtle_grain.jpg',
      name: '细腻颗粒',
      description: '简约颗粒纹理',
    ),
  ];

  @override
  String toString() {
    return 'ReaderBackground(type: $type, colorIndex: $colorIndex, customImageName: $customImageName, overlayOpacity: $overlayOpacity)';
  }
}
