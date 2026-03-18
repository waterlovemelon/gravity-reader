import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../models/reader_background.dart';

const String _prefKeyBackground = 'reader_background';
const String _prefKeyCustomImages = 'reader_custom_images';
const int _maxCustomImages = 10;

/// 自定义图片信息
class CustomBackgroundImage {
  final String path;
  final String fileName;
  final DateTime addedAt;

  const CustomBackgroundImage({
    required this.path,
    required this.fileName,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'fileName': fileName,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }

  factory CustomBackgroundImage.fromJson(Map<String, dynamic> json) {
    return CustomBackgroundImage(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int),
    );
  }
}

/// 阅读器背景状态管理
class ReaderBackgroundProvider with ChangeNotifier {
  ReaderBackground _background = ReaderBackground.defaultBackground;
  List<CustomBackgroundImage> _customImages = [];
  List<String> _presetImageIds = []; // 用户选择的预设图片ID列表

  ReaderBackgroundProvider() {
    _loadSettings();
  }

  // Getters
  ReaderBackground get background => _background;
  bool get isCustomImage => _background.type == BackgroundType.customImage;
  List<CustomBackgroundImage> get customImages => List.unmodifiable(_customImages);
  List<String> get presetImageIds => List.unmodifiable(_presetImageIds);

  /// 切换到预设颜色
  void setColorBackground(int colorIndex) {
    _background = ReaderBackground(
      type: BackgroundType.color,
      colorIndex: colorIndex,
      overlayOpacity: _background.overlayOpacity,
    );
    _saveSettings();
    notifyListeners();
  }

  /// 切换到自定义图片
  void setCustomImageBackground(String imagePath, String fileName) {
    _background = ReaderBackground(
      type: BackgroundType.customImage,
      customImagePath: imagePath,
      customImageName: fileName,
      overlayOpacity: _background.overlayOpacity,
      customImageAddedAt: DateTime.now(),
    );
    _saveSettings();
    notifyListeners();
  }

  /// 切换到预设图片
  void setPresetBackground(String presetId) {
    _background = ReaderBackground(
      type: BackgroundType.customImage,
      customImagePath: 'preset:$presetId',
      customImageName: 'preset',
      overlayOpacity: _background.overlayOpacity,
    );
    _saveSettings();
    notifyListeners();
  }

  /// 设置遮罩透明度
  void setOverlayOpacity(double opacity) {
    _background = _background.copyWith(overlayOpacity: opacity.clamp(0.0, 1.0));
    _saveSettings();
    notifyListeners();
  }

  /// 上传自定义图片
  Future<String?> uploadCustomImage({bool fromCamera = false}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = fromCamera
          ? await picker.pickImage(source: ImageSource.camera)
          : await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return null;

      // 检查是否达到上限
      if (_customImages.length >= _maxCustomImages) {
        throw Exception('自定义图片已达上限（$_maxCustomImages 张），请先删除一些图片');
      }

      // 获取文档目录
      final docDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${docDir.path}/reader_backgrounds');

      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      // 压缩图片
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        '${bgDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.jpg',
        quality: 85,
        minWidth: 1080 ~/ 2, // 压缩到540px宽度
        minHeight: 1920 ~/ 2,
        format: CompressFormat.jpeg,
      );

      if (compressedFile == null) {
        throw Exception('图片压缩失败');
      }

      // 添加到列表
      final customImage = CustomBackgroundImage(
        path: compressedFile.absolute.path,
        fileName: image.name,
        addedAt: DateTime.now(),
      );

      _customImages.add(customImage);
      await _saveCustomImages();

      return compressedFile.absolute.path;
    } catch (e) {
      debugPrint('Upload custom image error: $e');
      rethrow;
    }
  }

  /// 删除自定义图片
  Future<void> deleteCustomImage(String path) async {
    try {
      // 删除文件
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      // 从列表中移除
      _customImages.removeWhere((img) => img.path == path);
      await _saveCustomImages();

      // 如果当前背景是被删除的图片，切换回默认
      if (_background.customImagePath == path) {
        setColorBackground(0);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Delete custom image error: $e');
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载背景配置
      final bgJson = prefs.getString(_prefKeyBackground);
      if (bgJson != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(bgJson);
          _background = ReaderBackground.fromJson(data);
        } catch (e) {
          debugPrint('Parse background config error: $e');
          _background = ReaderBackground.defaultBackground;
        }
      }

      // 加载自定义图片列表
      final customImagesJson = prefs.getStringList(_prefKeyCustomImages);
      if (customImagesJson != null) {
        _customImages = customImagesJson
            .map((json) => CustomBackgroundImage.fromJson(
                 jsonDecode(json) as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Load background settings error: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBackground, jsonEncode(_background.toJson()));
    } catch (e) {
      debugPrint('Save background settings error: $e');
    }
  }

  /// 保存自定义图片列表
  Future<void> _saveCustomImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefKeyCustomImages,
        _customImages.map((img) => jsonEncode(img.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('Save custom images error: $e');
    }
  }
}
