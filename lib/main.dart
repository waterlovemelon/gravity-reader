import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:myreader/core/providers/shared_preferences_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/presentation/pages/main_navigation_page.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.myreader.audio.playback',
      androidNotificationChannelName: 'Audiobook Playback',
      androidNotificationOngoing: true,
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyReaderApp(),
    ),
  );
}

class MyReaderApp extends ConsumerStatefulWidget {
  const MyReaderApp({super.key});

  @override
  ConsumerState<MyReaderApp> createState() => _MyReaderAppState();
}

class _MyReaderAppState extends ConsumerState<MyReaderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(systemBrightnessProvider.notifier).state =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme = ref.watch(themeProvider).currentTheme;
    final appThemeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'MyReader',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme.toThemeData(brightness: Brightness.light),
      darkTheme: selectedTheme.toThemeData(brightness: Brightness.dark),
      themeMode: appThemeMode.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      localeListResolutionCallback: (locales, supportedLocales) {
        for (final locale in locales ?? const <Locale>[]) {
          if (locale.languageCode.toLowerCase().startsWith('zh')) {
            return const Locale('zh');
          }
          if (locale.languageCode.toLowerCase().startsWith('en')) {
            return const Locale('en');
          }
        }
        return const Locale('zh');
      },
      home: const MainNavigationPage(),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'reader') {
          final bookId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
          return MaterialPageRoute(
            builder: (context) => ReaderPage(bookId: bookId),
          );
        }

        return MaterialPageRoute(
          builder: (context) => const MainNavigationPage(),
        );
      },
    );
  }
}
