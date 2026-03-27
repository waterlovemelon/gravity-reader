import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';

/// 浏览器选择封面后返回的结果(字节+扩展名)
class CoverSearchResult {
  final Uint8List bytes;
  final String extension;
  const CoverSearchResult({required this.bytes, required this.extension});
}

class CoverSearchBrowserSheet extends ConsumerStatefulWidget {
  final String bookTitle;

  const CoverSearchBrowserSheet({super.key, required this.bookTitle});

  @override
  ConsumerState<CoverSearchBrowserSheet> createState() =>
      _CoverSearchBrowserSheetState();
}

class _CoverSearchBrowserSheetState
    extends ConsumerState<CoverSearchBrowserSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final searchQuery = Uri.encodeComponent('${widget.bookTitle} 封面');
    final searchUrl = 'https://www.bing.com/images/search?q=$searchQuery';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CoverPicker',
        onMessageReceived: (msg) {
          final url = msg.message;
          debugPrint('[CoverPicker] received: $url');
          if (url.isNotEmpty && mounted) {
            _onImageUrlReceived(url);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
              _injectScript();
            }
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint(
              '[CoverSearch] nav: ${url.length > 100 ? url.substring(0, 100) : url}',
            );
            if (url.contains('mediaurl=')) {
              final uri = Uri.parse(url);
              final mediaUrl = uri.queryParameters['mediaurl'];
              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                debugPrint('[CoverSearch] mediaurl: $mediaUrl');
                _onImageUrlReceived(mediaUrl);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller.loadRequest(Uri.parse(searchUrl));
  }

  void _injectScript() {
    _controller.runJavaScript(r'''
      (function() {
        if (window.__coverCleanup) window.__coverCleanup();
        console.log('[CoverSearch] script injected');

        function getImgUrl(el) {
          if (!el) return null;
          // 直接是 IMG
          if (el.tagName === 'IMG') {
            var s = el.getAttribute('data-src')
                 || el.getAttribute('data-iurl')
                 || el.getAttribute('data-src-hq')
                 || el.src || '';
            if (s.startsWith('http') && s.indexOf('data:') !== 0
                && !s.match(/\.(gif|svg)/i)
                && s.indexOf('bing.com/th?id=') === -1) {
              return s;
            }
          }
          // 检查子元素中的 IMG
          var childImgs = el.querySelectorAll('img');
          for (var i = 0; i < childImgs.length; i++) {
            var cs = childImgs[i].getAttribute('data-src')
                  || childImgs[i].getAttribute('data-iurl')
                  || childImgs[i].src || '';
            if (cs.startsWith('http') && cs.indexOf('data:') !== 0
                && !cs.match(/\.(gif|svg)/i)
                && cs.indexOf('bing.com/th?id=') === -1) {
              return cs;
            }
          }
          // A 标签直接指向图片
          if (el.tagName === 'A') {
            var h = el.href || '';
            if (h.match(/\.(jpg|jpeg|png|webp)/i) && h.startsWith('http')) return h;
          }
          return null;
        }

        function handler(e) {
          var tag = e.target.tagName || '?';
          console.log('[CoverSearch] click on: ' + tag);

          // 方法1: 直接从点击目标和子元素找
          var url = getImgUrl(e.target);
          // 方法2: 用点击坐标找附近元素
          if (!url && e.touches && e.touches.length) {
            url = getImgUrl(document.elementFromPoint(e.touches[0].clientX, e.touches[0].clientY));
          }
          if (!url) {
            var x = e.clientX || 0, y = e.clientY || 0;
            if (x && y) {
              url = getImgUrl(document.elementFromPoint(x, y));
              // 再往周围偏移几像素试一下
              if (!url) url = getImgUrl(document.elementFromPoint(x + 30, y));
              if (!url) url = getImgUrl(document.elementFromPoint(x - 30, y));
              if (!url) url = getImgUrl(document.elementFromPoint(x, y + 30));
            }
          }

          if (url) {
            console.log('[CoverSearch] click found: ' + url.substring(0,120));
            window.__pickedImgUrl = url;
            CoverPicker.postMessage(url);
            e.preventDefault();
            e.stopPropagation();
          } else {
            console.log('[CoverSearch] click: no img found from ' + tag);
          }
        }

        document.addEventListener('click', handler, true);

        window.__coverCleanup = function() {
          document.removeEventListener('click', handler, true);
          delete window.__pickedImgUrl;
        };
      })();
    ''');
  }

  Future<void> _onImageUrlReceived(String imageUrl) async {
    final theme = ref.read(currentThemeProvider);

    // 用 HttpClient 下载到内存,绕过 iOS 沙盒限制
    Uint8List? imageBytes;
    try {
      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      final request = await client.getUrl(Uri.parse(imageUrl));
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)',
      );
      request.headers.set('Referer', 'https://www.bing.com/');
      final response = await request.close();
      debugPrint('[CoverSearch] download status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[CoverSearch] download failed: ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}');
      }
      imageBytes = await consolidateHttpClientResponseBytes(response);
      debugPrint('[CoverSearch] downloaded ${imageBytes.length} bytes');
      client.close();
    } catch (e) {
      debugPrint('[CoverSearch] download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleText.of(
              context,
              zh: '图片下载失败，请换一张',
              en: 'Download failed, try another',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _ImageConfirmDialog(imageBytes: imageBytes!, theme: theme),
    );

    if (confirmed == true && mounted) {
      final ext = _detectExt(imageUrl, imageBytes!);
      Navigator.of(
        context,
      ).pop(CoverSearchResult(bytes: imageBytes!, extension: ext));
    }
  }

  static String _detectExt(String url, Uint8List bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
      if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'webp';
      if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
    }
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.95,
      child: Column(
        children: [
          // 顶部栏
          Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        LocaleText.of(
                          context,
                          zh: '搜索封面 - ${widget.bookTitle}',
                          en: 'Search Cover',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                      onPressed: () async {
                        if (await _controller.canGoBack()) {
                          _controller.goBack();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => _controller.reload(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 提示条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: theme.primaryColor.withValues(alpha: 0.08),
            child: Text(
              LocaleText.of(
                context,
                zh: '点击图片即可设为封面',
                en: 'Tap an image to set as cover',
              ),
              style: TextStyle(fontSize: 12, color: theme.primaryColor),
              textAlign: TextAlign.center,
            ),
          ),
          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: _controller,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
                if (_isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: theme.primaryColor,
                      minHeight: 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageConfirmDialog extends StatelessWidget {
  final Uint8List imageBytes;
  final AppThemeData theme;

  const _ImageConfirmDialog({required this.imageBytes, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: theme.cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LocaleText.of(
                context,
                zh: '使用此图片作为封面？',
                en: 'Use this image as cover?',
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textColor,
                      side: BorderSide(color: theme.dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(LocaleText.of(context, zh: '取消', en: 'Cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      LocaleText.of(context, zh: '设为封面', en: 'Set Cover'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
