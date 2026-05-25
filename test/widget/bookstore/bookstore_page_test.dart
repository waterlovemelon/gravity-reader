import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/remote_catalog_providers.dart';
import 'package:myreader/core/providers/shared_preferences_provider.dart';
import 'package:myreader/data/services/remote_catalog/remote_book_import_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';
import 'package:myreader/presentation/pages/bookstore/bookstore_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('bookstore shows featured shelf layout for catalog browsing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();

    final books = [
      const CatalogBookSummary(
        id: 'featured',
        title: '瓦尔登湖',
        author: '梭罗',
        description: '湖边生活与自然沉思。',
        coverUrl: '',
        downloadUrl: 'https://example.com/featured.epub',
        language: '中文',
        chapterCount: 18,
      ),
      const CatalogBookSummary(
        id: 'moon',
        title: '月亮与六便士',
        author: '毛姆',
        description: '理想与现实的偏航。',
        coverUrl: '',
        downloadUrl: 'https://example.com/moon.epub',
        language: '中文',
        chapterCount: 21,
      ),
      const CatalogBookSummary(
        id: 'outsider',
        title: '局外人',
        author: '加缪',
        description: '荒诞与疏离。',
        coverUrl: '',
        downloadUrl: 'https://example.com/outsider.epub',
        language: '法语',
        chapterCount: 12,
      ),
    ];

    final localBooks = [
      Book(
        id: remoteCatalogLocalBookId(books.first),
        title: books.first.title,
        author: books.first.author,
        epubPath: '/tmp/featured.epub',
        fileSize: 42,
        importedAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          booksProvider.overrideWith(
            (ref) => _FakeBooksNotifier(ref, BooksState(books: localBooks)),
          ),
          remoteCatalogProvider.overrideWith(
            (ref) => _FakeRemoteCatalogNotifier(
              ref,
              RemoteCatalogState(books: books),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BookstorePage(),
        ),
      ),
    );

    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(const Color(0xFFF3E6D4)));
    expect(find.text('像逛书架一样找书'), findsNothing);
    expect(find.text('编辑推荐'), findsOneWidget);
    expect(find.text('大家都在读'), findsOneWidget);
    expect(find.text('瓦尔登湖'), findsAtLeastNWidgets(1));
    expect(find.text('梭罗'), findsAtLeastNWidgets(1));
    expect(find.text('轻点阅读'), findsNothing);
    expect(find.text('轻点加入'), findsNothing);
  });

  testWidgets('bookstore shelf cards do not overflow on narrow iPhone width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final books = List.generate(
      6,
      (index) => CatalogBookSummary(
        id: 'book-$index',
        title: 'A very long title $index for overflow checks',
        author: 'Anonymous',
        description: 'desc',
        coverUrl: '',
        downloadUrl: 'https://example.com/$index.epub',
        language: 'EPUB',
        chapterCount: 12,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          booksProvider.overrideWith(
            (ref) => _FakeBooksNotifier(ref, const BooksState()),
          ),
          remoteCatalogProvider.overrideWith(
            (ref) => _FakeRemoteCatalogNotifier(
              ref,
              RemoteCatalogState(books: books),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BookstorePage(),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookstore uses three columns on iPhone 17 Pro width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final books = List.generate(
      7,
      (index) => CatalogBookSummary(
        id: 'grid-$index',
        title: 'Grid Book $index',
        author: 'Author $index',
        description: '',
        coverUrl: '',
        downloadUrl: 'https://example.com/grid-$index.epub',
        language: 'EPUB',
        chapterCount: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          booksProvider.overrideWith(
            (ref) => _FakeBooksNotifier(ref, const BooksState()),
          ),
          remoteCatalogProvider.overrideWith(
            (ref) => _FakeRemoteCatalogNotifier(
              ref,
              RemoteCatalogState(books: books),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BookstorePage(),
        ),
      ),
    );

    await tester.pump();
    final titleFinders = [
      find.text('Grid Book 1'),
      find.text('Grid Book 2'),
      find.text('Grid Book 3'),
    ];
    final firstRowY = tester.getTopLeft(titleFinders.first).dy;
    final sameRow = titleFinders.where((finder) {
      final y = tester.getTopLeft(finder).dy;
      return (y - firstRowY).abs() < 1;
    }).length;
    expect(sameRow, 3);
  });
}

class _FakeBooksNotifier extends BooksNotifier {
  _FakeBooksNotifier(super.ref, BooksState initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> loadBooks() async {}

  @override
  Future<void> addBook(Book book) async {
    state = state.copyWith(books: [...state.books, book]);
  }
}

class _FakeRemoteCatalogNotifier extends RemoteCatalogNotifier {
  _FakeRemoteCatalogNotifier(super.ref, RemoteCatalogState initialState)
    : super() {
    state = initialState;
  }

  @override
  Future<void> loadBooks({bool force = false}) async {}
}
