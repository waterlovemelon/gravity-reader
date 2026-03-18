import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/reader_background.dart';
import '../../../core/providers/reader_background_provider.dart';

/// 背景图片卡片组件
class BackgroundImageCard extends StatelessWidget {
  final PresetBackground? preset;
  final CustomBackgroundImage? custom;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const BackgroundImageCard({
    super.key,
    this.preset,
    this.custom,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onLongPress,
  }) : assert(preset != null || custom != null, 'Either preset or custom must be provided');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReaderBackgroundProvider>();

    // 获取图片路径
    ImageProvider? imageProvider;
    String? name;
    String? description;

    if (preset != null) {
      imageProvider = AssetImage(preset!.assetPath);
      name = preset!.name;
      description = preset!.description;
    } else if (custom != null) {
      imageProvider = FileImage(File(custom!.path));
      name = custom!.fileName;
    }

    return Stack(
      children: [
        // 图片卡片
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: isSelected ? 3 : 0,
                ),
                boxShadow: isSelected
                    ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景图片
                    if (imageProvider != null)
                      Image(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 32),
                          );
                        },
                      ),
                    // 遮罩效果（如果选中且遮罩已启用）
                    if (isSelected && provider.background.type == BackgroundType.customImage)
                      Container(
                        color: Colors.black.withOpacity(provider.background.overlayOpacity),
                      ),
                    // 选中指示器
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // 删除按钮（仅自定义图片）
                    if (custom != null && onDelete != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    // 名称标签
                    if (name != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Text(
                            name!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 遮罩强度调节器
class OverlayOpacitySlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const OverlayOpacitySlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.layers_rounded,
                    size: 18,
                    color: textColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '遮罩强度',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: textColor.withOpacity(0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: textColor.withOpacity(0.15),
                    thumbColor: primaryColor,
                    overlayColor: primaryColor.withOpacity(0.1),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: value,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(value * 100).round()}%',
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.block_rounded,
                size: 18,
                color: textColor.withOpacity(0.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '调节遮罩以改善文字可读性',
          style: TextStyle(
            fontSize: 11,
            color: textColor.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
