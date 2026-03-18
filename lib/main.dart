import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/presentation/pages/main_navigation_page.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.myreader.audio.playback',
      androidNotificationChannelName: 'Audiobook Playback',
      androidNotificationOngoing: true,
    );
  }
  runApp(const ProviderScope(child: MyReaderApp()));
}

class MyReaderApp extends StatelessWidget {
  const MyReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // 监听主题变化
        final currentTheme = ref.watch(currentThemeProvider);

        return MaterialApp(
          title: 'MyReader',
          debugShowCheckedModeBanner: false,
          theme: currentTheme.toThemeData(),
          themeMode: ThemeMode.light, // 当前主要支持浅色主题
          home: const MainNavigationPage(),
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name ?? '');

            if (uri.pathSegments.isNotEmpty &&
                uri.pathSegments[0] == 'reader') {
              final bookId = uri.pathSegments.length > 1
                  ? uri.pathSegments[1]
                  : '';
              return MaterialPageRoute(
                builder: (context) => ReaderPage(bookId: bookId),
              );
            }

            return MaterialPageRoute(
              builder: (context) => const MainNavigationPage(),
            );
          },
        );
      },
    );
  }
}
