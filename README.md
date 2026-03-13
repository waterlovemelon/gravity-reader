# Gravity Reader - 跨平台阅读器应用

Flutter跨平台阅读应用（iOS + Android），支持EPUB/TXT格式，内置听书功能。

## 项目概述

将iOS原生阅读应用重写为跨平台应用，使用Flutter + Clean Architecture架构。

## 技术栈

- **Flutter 3.24+** (Dart 3.9+)
- **状态管理**: Riverpod
- **数据库**: SQLite (sqflite)
- **EPUB引擎**: Flureadium (基于Readium)

## 核心功能

### 已实现功能

- ✅ 基础架构搭建完成
- ✅ 数据模型定义完成
- ✅ 实体类定义完成
- ✅ TXT书籍阅读器（自动分页、目录导航）
- ✅ 阅读器界面（主题切换、亮度调节、字体设置）
- ✅ **听书功能**（悬浮🎧按钮 + 外部 `ms-ra-forwarder` TTS 服务）

### 听书功能

阅读器右上角悬浮"🎧"按钮，点击后弹出听书页面：

**特性：**
- 🎧 通过外部 `ms-ra-forwarder` 服务生成音频并播放（支持 iOS 和 Android）
- 🔁 云端 TTS 超时后自动回退到本地 TTS，后续自动重试云端恢复
- 📄 当前页面文本朗读
- ▶️ 播放/暂停/停止控制
- ⏭️ 上一页/下一页切换
- 🎚️ 进度条拖拽跳转
- 🔊 语速调节（0.5x - 2.0x）
- 📊 实时状态显示（播放中/已暂停）
- 🚀 **双击中间区域即刻开始听书**

**操作方式：**
1. **双击**阅读页面中间区域 → 直接开始听书
2. 点击右上角**悬浮🎧按钮** → 打开听书页面

**UI设计亮点：**
- 🎨 深色主题背景（`#1A1A1A`）
- 🎯 Material Design风格按钮
- 💧 涟漪点击效果
- 🔵 蓝色主题进度条（`#2196F3`）
- 📱 清晰的视觉层次
- 👆 大尺寸触控区域

## 项目结构

```
lib/
├── core/           # 核心模块
├── domain/         # 领域层
├── data/           # 数据层
├── presentation/   # 表现层
│   └── pages/
│       └── reader/
│           ├── reader_page.dart     # 阅读器
│           └── audiobook_page.dart  # 听书页面 ✓
```

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行前准备 dart-define 配置文件
# 1) 复制模板
cp env/dart_defines.example.json env/dart_defines.local.json
# 2) 编辑 env/dart_defines.local.json（至少配置 TTS_BASE_URL）

# 运行
flutter run -d ios \
  --dart-define-from-file=env/dart_defines.local.json

flutter run -d android \
  --dart-define-from-file=env/dart_defines.local.json

# 代码检查
flutter analyze
dart format lib/
```

## 文档

详细计划：`.sisyphus/plans/myreader-cross-platform.md`
