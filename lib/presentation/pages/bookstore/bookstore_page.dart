import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/placeholder_cover_assets.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/remote_catalog_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/data/services/remote_catalog/remote_book_import_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';

class BookstorePage extends ConsumerStatefulWidget {
  const BookstorePage({super.key});

  @override
  ConsumerState<BookstorePage> createState() => _BookstorePageState();
}

class _BookstorePageState extends ConsumerState<BookstorePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(booksProvider.notifier).loadBooks();
      await ref.read(remoteCatalogProvider.notifier).loadBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final catalogState = ref.watch(remoteCatalogProvider);
    final localBooks = ref.watch(booksProvider).books;
    final filteredBooks = _filterBooks(catalogState.books, _query);
    final featuredBook = filteredBooks.isEmpty ? null : filteredBooks.first;
    final hasQuery = _query.trim().isNotEmpty;
    final shelfBooks = hasQuery
        ? filteredBooks
        : filteredBooks.length > 1
        ? filteredBooks.sublist(1)
        : filteredBooks;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          _text(zh: '书城', en: 'Bookstore'),
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: theme.textColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _text(zh: '刷新', en: 'Refresh'),
            onPressed: () => _refresh(force: true),
            icon: Icon(
              Icons.refresh_rounded,
              color: Color.lerp(
                theme.primaryColor,
                const Color(0xFF7E5E48),
                0.2,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchField(
                      controller: _searchController,
                      theme: theme,
                      hintText: _text(
                        zh: '搜索书名、作者',
                        en: 'Search title or author',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (catalogState.isLoading && catalogState.books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (catalogState.error != null && catalogState.books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _BookstoreErrorState(
                  message: _text(zh: '书城加载失败', en: 'Failed to load bookstore'),
                  detail: catalogState.error!,
                  onRetry: () => _refresh(force: true),
                ),
              )
            else if (filteredBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _text(zh: '没有找到匹配的书', en: 'No matching books'),
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            else ...[
              if (!hasQuery && featuredBook != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _BookstoreFeaturedSection(
                      theme: theme,
                      sectionTitle: _text(zh: '编辑推荐', en: 'Editor Picks'),
                      sectionNote: _text(zh: '本周精选', en: 'Weekly pick'),
                      book: featuredBook,
                      localBook: _localBookFor(featuredBook, localBooks),
                      onAdd: () => _addToLibrary(featuredBook),
                      onRead: _localBookFor(featuredBook, localBooks) == null
                          ? null
                          : () => _openReader(
                              _localBookFor(featuredBook, localBooks)!,
                            ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _BookstoreSectionHeader(
                    theme: theme,
                    title: hasQuery
                        ? _text(zh: '搜索结果', en: 'Results')
                        : _text(zh: '大家都在读', en: 'Popular Reads'),
                    note: hasQuery
                        ? _text(
                            zh: '共 ${filteredBooks.length} 本',
                            en: '${filteredBooks.length} books',
                          )
                        : _text(zh: '每周更新', en: 'Updated weekly'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 116),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCountForWidth(
                      MediaQuery.of(context).size.width,
                    ),
                    childAspectRatio: 0.58,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final catalogBook = shelfBooks[index];
                    final localBook = _localBookFor(catalogBook, localBooks);
                    return _BookstoreGridCard(
                      theme: theme,
                      book: catalogBook,
                      localBook: localBook,
                      onAdd: () => _addToLibrary(catalogBook),
                      onRead: localBook == null
                          ? null
                          : () => _openReader(localBook),
                    );
                  }, childCount: shelfBooks.length),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _gridCountForWidth(double width) {
    if (width >= 1200) {
      return 5;
    }
    if (width >= 900) {
      return 4;
    }
    if (width >= 390) {
      return 3;
    }
    return 2;
  }

  Future<void> _refresh({required bool force}) async {
    await ref.read(remoteCatalogProvider.notifier).loadBooks(force: force);
  }

  Future<void> _addToLibrary(CatalogBookSummary catalogBook) async {
    try {
      final book = await ref
          .read(remoteCatalogProvider.notifier)
          .addToLibrary(catalogBook);
      if (!mounted) {
        return;
      }
      _showMessage(
        LocaleText.isChinese(context)
            ? '已加入书架：《${book.title}》'
            : 'Added to library: ${book.title}',
      );
      await _openReader(book);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('${_text(zh: '加入书架失败', en: 'Failed to add book')}: $e');
    }
  }

  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(bookId: book.id, initialBook: book),
      ),
    );
    if (!mounted) {
      return;
    }
    await ref.read(booksProvider.notifier).loadBooks();
  }

  Book? _localBookFor(CatalogBookSummary catalogBook, List<Book> localBooks) {
    final localId = remoteCatalogLocalBookId(catalogBook);
    for (final book in localBooks) {
      if (book.id == localId) {
        return book;
      }
    }
    return null;
  }

  List<CatalogBookSummary> _filterBooks(
    List<CatalogBookSummary> books,
    String query,
  ) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return books;
    }
    return books
        .where((book) {
          final value = _normalize('${book.title} ${book.author}');
          return value.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s\-_.,:;!?，。、《》]+'), '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _text({required String zh, required String en}) {
    return LocaleText.of(context, zh: zh, en: en);
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final AppThemeData theme;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.theme,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(
      theme.dividerColor,
      const Color(0xFF9A7C64),
      0.24,
    )!;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Color.lerp(theme.cardBackgroundColor, Colors.white, 0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.4),
        ),
      ),
    );
  }
}

class _BookstoreFeaturedSection extends StatelessWidget {
  final AppThemeData theme;
  final CatalogBookSummary book;
  final Book? localBook;
  final VoidCallback onAdd;
  final VoidCallback? onRead;
  final String sectionTitle;
  final String sectionNote;

  const _BookstoreFeaturedSection({
    required this.theme,
    required this.book,
    required this.localBook,
    required this.onAdd,
    required this.onRead,
    required this.sectionTitle,
    required this.sectionNote,
  });

  @override
  Widget build(BuildContext context) {
    final isAdded = localBook != null;
    final surface = theme.cardBackgroundColor;
    final borderColor = theme.dividerColor.withValues(alpha: 0.3);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isAdded ? onRead : onAdd,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookstoreSectionHeader(
                  theme: theme,
                  title: sectionTitle,
                  note: sectionNote,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RemoteCover(
                      book: book,
                      width: 112,
                      height: 156,
                      borderRadius: 16,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.author.trim().isEmpty
                                ? 'Unknown'
                                : book.author,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookstoreSectionHeader extends StatelessWidget {
  final AppThemeData theme;
  final String title;
  final String note;

  const _BookstoreSectionHeader({
    required this.theme,
    required this.title,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          note,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
      ],
    );
  }
}

class _BookstoreGridCard extends StatelessWidget {
  final AppThemeData theme;
  final CatalogBookSummary book;
  final Book? localBook;
  final VoidCallback onAdd;
  final VoidCallback? onRead;

  const _BookstoreGridCard({
    required this.theme,
    required this.book,
    required this.localBook,
    required this.onAdd,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final isAdded = localBook != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isAdded ? onRead : onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: _RemoteCover(
                  book: book,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 14,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              book.title,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              book.author.trim().isNotEmpty ? book.author : '未知作者',
              style: TextStyle(
                fontSize: 9.5,
                height: 1,
                color: theme.secondaryTextColor.withValues(alpha: 0.78),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteCover extends StatelessWidget {
  final CatalogBookSummary book;
  final double width;
  final double? height;
  final double borderRadius;

  const _RemoteCover({
    required this.book,
    this.width = 78,
    this.height = 112,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cover = book.coverUrl.trim().isEmpty
        ? _PlaceholderAssetCover(book: book)
        : Image.network(
            book.coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _PlaceholderAssetCover(book: book),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: height == null
            ? AspectRatio(aspectRatio: 0.72, child: cover)
            : cover,
      ),
    );
  }
}

class _PlaceholderAssetCover extends StatelessWidget {
  final CatalogBookSummary book;

  const _PlaceholderAssetCover({required this.book});

  @override
  Widget build(BuildContext context) {
    final assetPath =
        placeholderCoverAssets[book.id.hashCode.abs() %
            placeholderCoverAssets.length];
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F0E7), Color(0xFFADC4A7)],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFF64745D),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _BookstoreErrorState extends ConsumerWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;

  const _BookstoreErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
              color: Color(0xFFF44336),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(LocaleText.of(context, zh: '重试', en: 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
