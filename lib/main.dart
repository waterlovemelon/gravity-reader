import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/presentation/pages/main_navigation_page.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';

void main() {
  runApp(const ProviderScope(child: MyReaderApp()));
}

class MyReaderApp extends StatelessWidget {
  const MyReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
