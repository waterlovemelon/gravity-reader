import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myreader/core/constants/placeholder_cover_assets.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/bookmark_providers.dart';
import 'package:myreader/core/providers/category_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/data/services/txt_import_cache_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/flureadium_integration/epub_parser.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';
import 'package:myreader/presentation/widgets/bookshelf/bookshelf_grid_widget.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TxtImportCacheService _txtImportCacheService =
      const TxtImportCacheService();
  bool _isSearching = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = <String>{};
  OverlayEntry? _topNoticeEntry;
  AnimationController? _topNoticeController;
  Timer? _topNoticeTimer;

  void _logOpenTrace(String traceId, int startedAtMicros, String message) {
    final elapsedMs =
        (DateTime.now().microsecondsSinceEpoch - startedAtMicros) / 1000.0;
    debugPrint(
      '[open-book][$traceId][${elapsedMs.toStringAsFixed(1)}ms] $message',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(booksProvider.notifier).loadBooks();
      await ref.read(categoriesProvider.notifier).loadCategories();
      final books = ref.read(booksProvider).books;
      await ref.read(ttsProvider.notifier).warmUpVoicesForBooks(books);
    });
  }

  @override
  void dispose() {
    _topNoticeTimer?.cancel();
    _topNoticeController?.dispose();
    _topNoticeEntry?.remove();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    final booksState = ref.watch(booksProvider);
    final progressAsync = ref.watch(allReadingProgressProvider);
    final progressByBookId = progressAsync.valueOrNull ?? const {};
    final currentBook = _resolveCurrentBook(
      booksState.books,
      progressByBookId,
      booksState.sortMode,
    );
    final shelfBooks = currentBook == null
        ? booksState.books
        : booksState.books.where((book) => book.id != currentBook.id).toList();
    final allVisibleSelected =
        shelfBooks.isNotEmpty &&
        shelfBooks.every((book) => _selectedBookIds.contains(book.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _text(zh: '搜索书名或作者', en: 'Search title or author'),
                  border: InputBorder.none,
                ),
                onChanged: _handleSearchChanged,
              )
            : Text(
                _text(zh: '书架', en: 'Library'),
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
        actions: [
          TextButton(
            onPressed: _toggleSelectionMode,
            child: Text(
              _isSelectionMode
                  ? _text(zh: '完成', en: 'Done')
                  : _text(zh: '编辑', en: 'Edit'),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.textColor.withValues(alpha: 0.78),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _importBook,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshShelf,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isSearching &&
                            currentBook != null &&
                            !_isSelectionMode) ...[
                          _CurrentlyReadingCard(
                            book: currentBook,
                            progress:
                                progressByBookId[currentBook.id]?.percentage,
                            theme: theme,
                            onTap: () => _openReader(currentBook),
                            onListenTap: () => _handleListenTap(currentBook),
                          ),
                        ],
                        SizedBox(
                          height:
                              !_isSearching &&
                                  currentBook != null &&
                                  !_isSelectionMode
                              ? 16
                              : 8,
                        ),
                        Row(
                          children: [
                            Text(
                              _isSearching
                                  ? _text(zh: '搜索结果', en: 'Results')
                                  : _text(zh: '全部书籍', en: 'All Books'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.textColor,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _showSortSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _sortLabel(booksState.sortMode),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: theme.secondaryTextColor,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: theme.secondaryTextColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isSelectionMode) ...[
                              const SizedBox(width: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: shelfBooks.isEmpty
                                    ? null
                                    : () => _toggleSelectAll(
                                        shelfBooks,
                                        allVisibleSelected,
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    allVisibleSelected
                                        ? _text(zh: '取消全选', en: 'Clear All')
                                        : _text(zh: '全选', en: 'Select All'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: theme.secondaryTextColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (booksState.isLoading && booksState.books.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (booksState.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.secondaryTextColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _text(zh: '加载书籍失败', en: 'Failed to load books'),
                              style: TextStyle(color: theme.secondaryTextColor),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _refreshShelf,
                              child: Text(_text(zh: '重试', en: 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  BookshelfGridWidget(
                    books: shelfBooks,
                    progressByBookId: progressByBookId,
                    selectedBookIds: _selectedBookIds,
                    selectionMode: _isSelectionMode,
                    onBookTap: _handleBookTap,
                    onBookMenuRequest: _handleBookMenuRequest,
                  ),
              ],
            ),
          ),
          if (_isSelectionMode)
            _SelectionBar(
              selectedCount: _selectedBookIds.length,
              onMoveCategory: _selectedBookIds.isEmpty
                  ? null
                  : _showBatchCategorySheet,
              onDelete: _selectedBookIds.isEmpty
                  ? null
                  : _confirmDeleteSelected,
            ),
        ],
      ),
    );
  }

  void _handleSearchChanged(String value) {
    if (value.isNotEmpty) {
      ref.read(booksProvider.notifier).searchBooks(value);
    } else {
      ref.read(booksProvider.notifier).loadBooks();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(booksProvider.notifier).loadBooks();
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedBookIds.clear();
      }
    });
  }

  Future<void> _refreshShelf() async {
    ref.invalidate(allReadingProgressProvider);
    await ref.read(booksProvider.notifier).loadBooks();
  }

  void _handleBookTap(Book book) {
    if (_isSelectionMode) {
      _toggleBookSelection(book.id);
      return;
    }
    _openReader(book);
  }

  Future<void> _handleBookMenuRequest(Book book, Offset globalPosition) async {
    if (_isSelectionMode || !mounted) {
      return;
    }
    final action = await showGeneralDialog<_BookQuickAction>(
      context: context,
      barrierLabel: _text(zh: '书籍菜单', en: 'Book menu'),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, __, ___) => _BookContextMenuPopup(
        book: book,
        anchor: globalPosition,
        theme: ref.read(currentThemeProvider),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

    switch (action) {
      case _BookQuickAction.details:
        await _showBookDetailsSheet(book);
        break;
      case _BookQuickAction.changeCover:
        await _changeBookCover(book);
        break;
      case _BookQuickAction.delete:
        await _confirmDeleteBook(book);
        break;
      case _BookQuickAction.stats:
        await _showReadingStatsSheet(book);
        break;
      case null:
        break;
    }
  }

  void _toggleBookSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _toggleSelectAll(List<Book> books, bool allSelected) {
    setState(() {
      if (allSelected) {
        for (final book in books) {
          _selectedBookIds.remove(book.id);
        }
      } else {
        for (final book in books) {
          _selectedBookIds.add(book.id);
        }
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedBookIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(zh: '批量删除', en: 'Delete Selected')),
        content: Text(
          LocaleText.isChinese(context)
              ? '确认删除已选的 $count 本书吗？'
              : 'Delete $count selected books?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text(zh: '取消', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text(zh: '删除', en: 'Delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final ids = _selectedBookIds.toList(growable: false);
    for (final id in ids) {
      await _deleteBookAndAssets(id);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBookIds.clear();
      _isSelectionMode = false;
    });
    ref.invalidate(allReadingProgressProvider);
  }

  Future<void> _confirmDeleteBook(Book book) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(zh: '删除书籍', en: 'Delete Book')),
        content: Text(
          LocaleText.isChinese(context)
              ? '确认删除《${book.title}》吗？'
              : 'Delete "${book.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text(zh: '取消', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text(zh: '删除', en: 'Delete')),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteBookAndAssets(book.id);
    if (!mounted) {
      return;
    }
    ref.invalidate(allReadingProgressProvider);
  }

  Future<void> _showSortSheet() async {
    final theme = ref.read(currentThemeProvider);
    final currentMode = ref.read(booksProvider).sortMode;
    final mode = await showModalBottomSheet<BookSortMode>(
      context: context,
      backgroundColor: theme.cardBackgroundColor,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  _text(zh: '排序方式', en: 'Sort By'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...BookSortMode.values.map((mode) {
                final selected = mode == currentMode;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(_sortMenuLabel(mode)),
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: theme.primaryColor)
                      : null,
                  onTap: () => Navigator.pop(context, mode),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (mode == null) {
      return;
    }
    await ref.read(booksProvider.notifier).setSortMode(mode);
  }

  Future<void> _showBatchCategorySheet() async {
    final theme = ref.read(currentThemeProvider);
    final categoriesState = ref.read(categoriesProvider);
    final categories = categoriesState.categories;
    final result = await showModalBottomSheet<_CategorySelectionResult?>(
      context: context,
      backgroundColor: theme.cardBackgroundColor,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  _text(zh: '移动到分类', en: 'Move To Category'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: Text(_text(zh: '新建分类', en: 'New Category')),
                onTap: () => Navigator.pop(
                  context,
                  const _CategorySelectionResult.create(),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.clear_all_rounded),
                title: Text(_text(zh: '未分类', en: 'Uncategorized')),
                onTap: () => Navigator.pop(
                  context,
                  const _CategorySelectionResult.existing(''),
                ),
              ),
              ...categories.map(
                (category) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: _categoryColor(category.color),
                  ),
                  title: Text(category.name),
                  onTap: () => Navigator.pop(
                    context,
                    _CategorySelectionResult.existing(category.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) {
      return;
    }
    if (result.shouldCreate) {
      await _createCategoryAndMoveSelected();
      return;
    }
    final categoryId = result.categoryId;
    await _moveSelectedToCategory(categoryId.isEmpty ? null : categoryId);
  }

  Future<void> _moveSelectedToCategory(String? categoryId) async {
    final updateBook = ref.read(updateBookUseCaseProvider);
    final books = ref.read(booksProvider).books;
    final selectedBooks = books
        .where((book) => _selectedBookIds.contains(book.id))
        .toList(growable: false);

    for (final book in selectedBooks) {
      await updateBook(
        Book(
          id: book.id,
          title: book.title,
          author: book.author,
          coverPath: book.coverPath,
          epubPath: book.epubPath,
          totalPages: book.totalPages,
          fileSize: book.fileSize,
          importedAt: book.importedAt,
          lastReadAt: book.lastReadAt,
          categoryId: categoryId,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    await ref.read(booksProvider.notifier).loadBooks();
    setState(() {
      _selectedBookIds.clear();
      _isSelectionMode = false;
    });
    _showTopNotice(
      message: categoryId == null
          ? _text(zh: '已移出分类', en: 'Removed from category')
          : _text(zh: '已更新书籍分类', en: 'Book category updated'),
      kind: _TopNoticeKind.success,
    );
  }

  Future<void> _createCategoryAndMoveSelected() async {
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(zh: '新建分类', en: 'New Category')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: _text(zh: '输入分类名称', en: 'Enter category name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_text(zh: '取消', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.pop(context, name);
            },
            child: Text(_text(zh: '创建', en: 'Create')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (createdName == null || createdName.trim().isEmpty) {
      return;
    }

    final notifier = ref.read(categoriesProvider.notifier);
    final existing = ref.read(categoriesProvider).categories;
    final maxSortOrder = existing.isEmpty
        ? -1
        : existing
              .map((item) => item.sortOrder)
              .reduce((a, b) => a > b ? a : b);
    final category = Category(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: createdName.trim(),
      color: existing.length % 6,
      createdAt: DateTime.now(),
      sortOrder: maxSortOrder + 1,
    );

    await notifier.saveCategory(category);
    if (!mounted) {
      return;
    }
    await _moveSelectedToCategory(category.id);
  }

  Book? _resolveCurrentBook(
    List<Book> books,
    Map<String, ReadingProgress> progressByBookId,
    BookSortMode sortMode,
  ) {
    if (books.isEmpty) {
      return null;
    }

    final candidates = books.where((book) {
      final progress = progressByBookId[book.id];
      return (progress?.percentage ?? 0) > 0 || book.lastReadAt != null;
    }).toList();

    if (candidates.isEmpty) {
      return books.first;
    }

    candidates.sort((a, b) {
      final aProgress = progressByBookId[a.id];
      final bProgress = progressByBookId[b.id];
      final aLast = aProgress?.lastReadAt ?? a.lastReadAt ?? a.importedAt;
      final bLast = bProgress?.lastReadAt ?? b.lastReadAt ?? b.importedAt;
      final byLastRead = bLast.compareTo(aLast);
      if (byLastRead != 0) {
        return byLastRead;
      }
      if (sortMode == BookSortMode.progress) {
        return (bProgress?.percentage ?? 0).compareTo(
          aProgress?.percentage ?? 0,
        );
      }
      return b.importedAt.compareTo(a.importedAt);
    });
    return candidates.first;
  }

  String _sortLabel(BookSortMode mode) {
    return LocaleText.isChinese(context)
        ? '按${_sortMenuLabel(mode)}'
        : _sortMenuLabel(mode);
  }

  String _sortMenuLabel(BookSortMode mode) {
    switch (mode) {
      case BookSortMode.latestAdded:
        return _text(zh: '最近导入', en: 'Recently Added');
      case BookSortMode.recentRead:
        return _text(zh: '最近阅读', en: 'Recently Read');
      case BookSortMode.progress:
        return _text(zh: '阅读进度', en: 'Progress');
      case BookSortMode.title:
        return _text(zh: '书名', en: 'Title');
      case BookSortMode.author:
        return _text(zh: '作者', en: 'Author');
    }
  }

  Future<void> _handleListenTap(Book book) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => ReaderPage(
          bookId: book.id,
          initialBook: book,
          autoStartFloatingPlayback: true,
          popAfterAutoStart: true,
          hiddenForAutoStart: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    ref.invalidate(allReadingProgressProvider);
  }

  Future<void> _showBookDetailsSheet(Book book) async {
    final theme = ref.read(currentThemeProvider);
    final categories = ref.read(categoriesProvider).categories;
    final categoryName = _categoryNameForBook(book, categories);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardBackgroundColor,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    height: 104,
                    child: BookCoverWidget(
                      book: book,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.author?.trim().isNotEmpty == true
                              ? book.author!
                              : _text(zh: '未知作者', en: 'Unknown Author'),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _BookMetaRow(
                label: _text(zh: '分类', en: 'Category'),
                value: categoryName,
              ),
              _BookMetaRow(
                label: _text(zh: '总页数', en: 'Pages'),
                value:
                    book.totalPages?.toString() ??
                    _text(zh: '未知', en: 'Unknown'),
              ),
              _BookMetaRow(
                label: _text(zh: '文件大小', en: 'File Size'),
                value: _formatFileSize(book.fileSize),
              ),
              _BookMetaRow(
                label: _text(zh: '导入时间', en: 'Imported'),
                value: _formatDateTime(book.importedAt),
              ),
              _BookMetaRow(
                label: _text(zh: '最近阅读', en: 'Last Read'),
                value: book.lastReadAt == null
                    ? _text(zh: '未开始', en: 'Not started')
                    : _formatDateTime(book.lastReadAt!),
              ),
              _BookMetaRow(
                label: _text(zh: '文件路径', en: 'Path'),
                value: book.epubPath,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReadingStatsSheet(Book book) async {
    final theme = ref.read(currentThemeProvider);
    final progress = ref.read(allReadingProgressProvider).valueOrNull?[book.id];
    final getNotesByBookId = ref.read(getNotesByBookIdUseCaseProvider);
    final getBookmarksByBookId = ref.read(getBookmarksByBookIdUseCaseProvider);
    final notes = await getNotesByBookId(book.id);
    final bookmarks = await getBookmarksByBookId(book.id);

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardBackgroundColor,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(zh: '阅读统计', en: 'Reading Stats'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              _BookStatRow(
                label: _text(zh: '阅读进度', en: 'Progress'),
                value: '${(((progress?.percentage ?? 0) * 100)).round()}%',
              ),
              _BookStatRow(
                label: _text(zh: '阅读时长', en: 'Reading Time'),
                value: _formatReadingDuration(
                  progress?.readingTimeSeconds ?? 0,
                ),
              ),
              _BookStatRow(
                label: _text(zh: '最近阅读', en: 'Last Read'),
                value: progress == null
                    ? _text(zh: '暂无记录', en: 'No record')
                    : _formatDateTime(progress.lastReadAt),
              ),
              _BookStatRow(
                label: _text(zh: '阅读位置', en: 'Position'),
                value: progress?.location.trim().isNotEmpty == true
                    ? progress!.location
                    : _text(zh: '暂无记录', en: 'No record'),
                maxLines: 2,
              ),
              _BookStatRow(
                label: _text(zh: '书签数量', en: 'Bookmarks'),
                value: '${bookmarks.length}',
              ),
              _BookStatRow(
                label: _text(zh: '笔记数量', en: 'Notes'),
                value: '${notes.length}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeBookCover(Book book) async {
    try {
      String? pickedPath;
      if (Platform.isIOS || Platform.isAndroid) {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 92,
        );
        pickedPath = image?.path;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          pickedPath = result.files.first.path;
        }
      }

      if (pickedPath == null || pickedPath.isEmpty) {
        return;
      }

      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        throw Exception(_text(zh: '图片文件不存在', en: 'Image file not found'));
      }

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final extension = pickedPath.contains('.')
          ? pickedPath.split('.').last.toLowerCase()
          : 'jpg';
      final targetPath =
          '${coversDir.path}/custom_cover_${book.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final copiedFile = await sourceFile.copy(targetPath);
      await FileImage(copiedFile).evict();

      await _updateBook(book, coverPath: copiedFile.path);

      final previousCoverPath = book.coverPath;
      if (previousCoverPath != null && previousCoverPath != copiedFile.path) {
        await _deleteManagedFile(
          previousCoverPath,
          managedFolderName: 'covers',
        );
      }

      if (!mounted) {
        return;
      }
      _showTopNotice(
        message: _text(zh: '封面已更新', en: 'Cover updated'),
        kind: _TopNoticeKind.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showTopNotice(
        message: '${_text(zh: '修改封面失败', en: 'Failed to update cover')}: $e',
        kind: _TopNoticeKind.error,
      );
    }
  }

  Future<void> _updateBook(
    Book source, {
    String? coverPath,
    String? categoryId,
  }) async {
    final updateBook = ref.read(updateBookUseCaseProvider);
    await updateBook(
      Book(
        id: source.id,
        title: source.title,
        author: source.author,
        coverPath: coverPath ?? source.coverPath,
        epubPath: source.epubPath,
        totalPages: source.totalPages,
        fileSize: source.fileSize,
        importedAt: source.importedAt,
        lastReadAt: source.lastReadAt,
        categoryId: categoryId ?? source.categoryId,
      ),
    );
    await ref.read(booksProvider.notifier).loadBooks();
  }

  Future<void> _deleteBookAndAssets(String bookId) async {
    final books = ref.read(booksProvider).books;
    Book? book;
    for (final item in books) {
      if (item.id == bookId) {
        book = item;
        break;
      }
    }

    try {
      if (book != null) {
        await _cleanupBookFiles(book);
      }
      await ref.read(booksProvider.notifier).deleteBook(bookId);
    } catch (e) {
      if (mounted) {
        _showTopNotice(
          message: '${_text(zh: '删除书籍失败', en: 'Failed to delete book')}: $e',
          kind: _TopNoticeKind.error,
        );
      }
    }
  }

  Future<void> _cleanupBookFiles(Book book) async {
    await _deleteManagedFile(book.epubPath, managedFolderName: 'books');
    await _deleteManagedFile(book.coverPath, managedFolderName: 'covers');
    await _txtImportCacheService.delete(book.id);
    await _deletePaginationCaches(book.id);
  }

  Future<void> _deleteManagedFile(
    String? path, {
    required String managedFolderName,
  }) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final managedDirPath = '${appDir.path}/$managedFolderName/';
      if (!path.contains(managedDirPath)) {
        return;
      }
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore missing/locked files so database deletion can still proceed.
    }
  }

  Future<void> _deletePaginationCaches(String bookId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/pagination_cache');
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final name = entity.path.split('/').last;
        if (name.startsWith('${bookId}_') && name.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Ignore pagination cache cleanup failures during book deletion.
    }
  }

  Future<void> _importBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;

      // Get extension from filename
      final pickedFileName = pickedFile.name;
      final fileExt = pickedFileName.split('.').last.toLowerCase();

      // Filter to only accept EPUB and TXT files
      if (fileExt != 'epub' && fileExt != 'txt') {
        if (!mounted) return;
        _showTopNotice(
          message: _text(
            zh: '请选择 EPUB 或 TXT 文件',
            en: 'Please choose an EPUB or TXT file',
          ),
          kind: _TopNoticeKind.info,
        );
        return;
      }

      if (pickedFile.path == null) return;

      // Show loading
      if (!mounted) return;
      _showLoadingDialog(_text(zh: '正在导入书籍...', en: 'Importing book...'));

      // Copy file to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final newPath = '${booksDir.path}/$fileName';
      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(newPath);

      final baseTitle = pickedFileName.replaceFirst(RegExp(r'\\.[^.]+$'), '');
      final bookId = DateTime.now().millisecondsSinceEpoch.toString();
      String? coverPath;
      String? title;
      String? author;
      int? totalPages;

      if (fileExt == 'epub') {
        // Parse EPUB for metadata
        final parser = EpubParserImpl();
        final parseResult = await parser.parse(newPath);
        title = parseResult.metadata.title;
        author = parseResult.metadata.author;
        totalPages = parseResult.totalPages > 0 ? parseResult.totalPages : null;

        // Extract cover if available
        if (parseResult.metadata.coverPath != null) {
          final coversDir = Directory('${appDir.path}/covers');
          if (!await coversDir.exists()) {
            await coversDir.create(recursive: true);
          }
          coverPath = await parser.extractCover(
            newPath,
            '${coversDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        }
      } else {
        final decoded = await _readTxtContent(newPath);
        final cacheData = await _txtImportCacheService.prepare(
          text: decoded.text,
          encoding: decoded.encoding,
        );
        await _txtImportCacheService.write(bookId: bookId, data: cacheData);
        title = baseTitle;
        totalPages = cacheData.chapters.isEmpty ? 1 : cacheData.chapters.length;
      }

      coverPath ??= await _createImportedPlaceholderCover(
        appDir: appDir,
        bookId: bookId,
      );

      // Create book entity
      final book = Book(
        id: bookId,
        title: title ?? baseTitle,
        author: author,
        coverPath: coverPath,
        epubPath: newPath,
        totalPages: totalPages,
        fileSize: pickedFile.size,
        importedAt: DateTime.now(),
      );

      // Save to database
      await ref.read(booksProvider.notifier).addBook(book);
      await ref
          .read(ttsProvider.notifier)
          .warmUpVoicesForBooks(ref.read(booksProvider).books);

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      _showTopNotice(
        message: LocaleText.isChinese(context)
            ? '已导入《${book.title}》'
            : 'Imported "${book.title}"',
        kind: _TopNoticeKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      _showTopNotice(
        message: '${_text(zh: '导入失败', en: 'Import failed')}: $e',
        kind: _TopNoticeKind.error,
      );
    }
  }

  Future<String?> _createImportedPlaceholderCover({
    required Directory appDir,
    required String bookId,
  }) async {
    try {
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final random = Random();
      final assetPath =
          placeholderCoverAssets[random.nextInt(placeholderCoverAssets.length)];
      final data = await rootBundle.load(assetPath);
      final outputPath = '${coversDir.path}/placeholder_$bookId.png';
      final file = File(outputPath);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Future<void> _openReader(Book book) async {
    final startedAtMicros = DateTime.now().microsecondsSinceEpoch;
    final traceId = '${book.id}-${startedAtMicros.toRadixString(36)}';
    _logOpenTrace(traceId, startedAtMicros, 'tap received: ${book.title}');
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 100),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, __, ___) => ReaderPage(
          bookId: book.id,
          initialBook: book,
          openTraceId: traceId,
          openStartedAtMicros: startedAtMicros,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.linearToEaseOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        ),
      ),
    );
    _logOpenTrace(traceId, startedAtMicros, 'reader popped');
    if (!mounted) {
      return;
    }
    await ref.read(booksProvider.notifier).loadBooks();
    ref.invalidate(allReadingProgressProvider);
  }

  Future<_DecodedTxtContent> _readTxtContent(String path) async {
    final bytes = await File(path).readAsBytes();

    // Prefer UTF-8, fallback to common Chinese encodings (GB18030/GBK), then tolerant decode.
    try {
      return _DecodedTxtContent(text: utf8.decode(bytes), encoding: 'utf8');
    } catch (_) {
      final gb18030Text = await CharsetConverter.decode('gb18030', bytes);
      if (_containsReadableCjk(gb18030Text)) {
        return _DecodedTxtContent(text: gb18030Text, encoding: 'gb18030');
      }

      final gbkText = await CharsetConverter.decode('gbk', bytes);
      if (_containsReadableCjk(gbkText)) {
        return _DecodedTxtContent(text: gbkText, encoding: 'gbk');
      }

      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (utf8Text.trim().isNotEmpty) {
        return _DecodedTxtContent(text: utf8Text, encoding: 'utf8_malformed');
      }

      final latinText = latin1.decode(bytes, allowInvalid: true);
      if (latinText.trim().isNotEmpty) {
        return _DecodedTxtContent(text: latinText, encoding: 'latin1');
      }

      if (gb18030Text.trim().isNotEmpty) {
        return _DecodedTxtContent(text: gb18030Text, encoding: 'gb18030');
      }
      if (gbkText.trim().isNotEmpty) {
        return _DecodedTxtContent(text: gbkText, encoding: 'gbk');
      }
      return _DecodedTxtContent(text: utf8Text, encoding: 'utf8_malformed');
    }
  }

  bool _containsReadableCjk(String text) {
    if (text.trim().isEmpty) {
      return false;
    }
    final cjkCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(text).length;
    final replacementCount = RegExp('\uFFFD').allMatches(text).length;
    if (replacementCount > text.length * 0.02) {
      return false;
    }
    if (cjkCount >= 12) {
      return true;
    }
    if (text.length < 80 && cjkCount >= 2) {
      return true;
    }
    return false;
  }

  Color _categoryColor(int colorIndex) {
    const colors = [
      Color(0xFF7AA37F),
      Color(0xFF6C97A9),
      Color(0xFFB28B63),
      Color(0xFF9A7AA0),
      Color(0xFFC27575),
      Color(0xFF7A9692),
    ];
    return colors[colorIndex.abs() % colors.length];
  }

  String _categoryNameForBook(Book book, List<Category> categories) {
    final categoryId = book.categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return _text(zh: '未分类', en: 'Uncategorized');
    }
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return _text(zh: '未分类', en: 'Uncategorized');
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final precision = unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  String _formatReadingDuration(int seconds) {
    if (seconds <= 0) {
      return _text(zh: '0 分钟', en: '0 min');
    }
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours <= 0) {
      return LocaleText.isChinese(context) ? '$minutes 分钟' : '$minutes min';
    }
    if (minutes == 0) {
      return LocaleText.isChinese(context) ? '$hours 小时' : '$hours hr';
    }
    return LocaleText.isChinese(context)
        ? '$hours 小时 $minutes 分钟'
        : '$hours hr $minutes min';
  }

  String _text({required String zh, required String en}) {
    return LocaleText.of(context, zh: zh, en: en);
  }

  void _showTopNotice({required String message, required _TopNoticeKind kind}) {
    if (!mounted) {
      return;
    }

    _topNoticeTimer?.cancel();

    final existingController = _topNoticeController;
    if (_topNoticeEntry != null && existingController != null) {
      final previousEntry = _topNoticeEntry;
      existingController.reverse().whenComplete(() {
        previousEntry?.remove();
        existingController.dispose();
      });
    }

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
    );
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _topNoticeController = controller;
    final entry = OverlayEntry(
      builder: (context) => _TopFloatingNotice(
        message: message,
        theme: ref.read(currentThemeProvider),
        kind: kind,
        animation: curved,
        onDismiss: _hideTopNotice,
      ),
    );
    _topNoticeEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    controller.forward();

    _topNoticeTimer = Timer(const Duration(milliseconds: 2400), () {
      _hideTopNotice();
    });
  }

  void _hideTopNotice() {
    _topNoticeTimer?.cancel();
    final controller = _topNoticeController;
    final entry = _topNoticeEntry;
    if (controller == null || entry == null) {
      return;
    }

    _topNoticeController = null;
    _topNoticeEntry = null;
    controller.reverse().whenComplete(() {
      entry.remove();
      controller.dispose();
    });
  }
}

class _DecodedTxtContent {
  final String text;
  final String encoding;

  const _DecodedTxtContent({required this.text, required this.encoding});
}

class _CategorySelectionResult {
  final String categoryId;
  final bool shouldCreate;

  const _CategorySelectionResult.existing(this.categoryId)
    : shouldCreate = false;

  const _CategorySelectionResult.create()
    : categoryId = '',
      shouldCreate = true;
}

enum _BookQuickAction { details, changeCover, delete, stats }

enum _TopNoticeKind { success, error, info }

class _CurrentlyReadingCard extends StatelessWidget {
  final Book book;
  final double? progress;
  final AppThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onListenTap;

  const _CurrentlyReadingCard({
    required this.book,
    required this.progress,
    required this.theme,
    required this.onTap,
    required this.onListenTap,
  });

  @override
  Widget build(BuildContext context) {
    final value = (progress ?? 0).clamp(0.0, 1.0);
    final warmAccent = Color.lerp(
      theme.primaryColor,
      const Color(0xFFE5A93D),
      0.42,
    )!;
    final cardBase = Color.lerp(theme.cardBackgroundColor, warmAccent, 0.18)!;
    final cardHighlight = Color.lerp(
      theme.cardBackgroundColor,
      warmAccent,
      0.3,
    )!;
    final borderColor = Color.lerp(theme.dividerColor, warmAccent, 0.36)!;
    final badgeBackground = warmAccent.withValues(alpha: 0.16);
    final badgeTextColor = Color.lerp(theme.textColor, warmAccent, 0.5)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardHighlight, cardBase, theme.cardBackgroundColor],
              stops: const [0, 0.45, 1],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: theme.textColor.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox(
            height: 136,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 106,
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: BookCoverWidget(
                      book: book,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            fontSize: 19.5,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          book.author?.trim().isNotEmpty == true
                              ? book.author!
                              : LocaleText.of(
                                  context,
                                  zh: '未知作者',
                                  en: 'Unknown Author',
                                ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.secondaryTextColor.withValues(
                              alpha: 0.9,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                LocaleText.of(
                                  context,
                                  zh: '阅读进度',
                                  en: 'Progress',
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.secondaryTextColor.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '${(value * 100).round()}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: theme.secondaryTextColor.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 4,
                            backgroundColor: theme.dividerColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBackground,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                LocaleText.of(
                                  context,
                                  zh: '正在阅读',
                                  en: 'Reading',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonal(
                              onPressed: onListenTap,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(86, 41),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                LocaleText.of(context, zh: '听书', en: 'Listen'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onMoveCategory;
  final VoidCallback? onDelete;

  const _SelectionBar({
    required this.selectedCount,
    required this.onMoveCategory,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 18,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Text(
                LocaleText.isChinese(context)
                    ? '已选 $selectedCount 本'
                    : '$selectedCount selected',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                LocaleText.of(
                  context,
                  zh: '可批量删除',
                  en: 'Bulk delete available',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onMoveCategory,
                child: Text(LocaleText.of(context, zh: '分类', en: 'Category')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onDelete,
                child: Text(LocaleText.of(context, zh: '删除', en: 'Delete')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookContextMenuPopup extends StatelessWidget {
  final Book book;
  final Offset anchor;
  final AppThemeData theme;

  const _BookContextMenuPopup({
    required this.book,
    required this.anchor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final author = book.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty;
    const menuWidth = 232.0;
    const menuRadius = 18.0;
    final estimatedMenuHeight = hasAuthor ? 286.0 : 270.0;
    final safeTop = mediaQuery.padding.top + 12;
    final safeLeft = 12.0;
    final safeRight = mediaQuery.size.width - menuWidth - 12;
    final left = anchor.dx.clamp(
      safeLeft,
      safeRight < safeLeft ? safeLeft : safeRight,
    );
    final maxTop = mediaQuery.size.height -
        mediaQuery.padding.bottom -
        estimatedMenuHeight -
        12;
    final showAboveAnchor =
        anchor.dy + estimatedMenuHeight >
            mediaQuery.size.height - mediaQuery.padding.bottom - 12 &&
        anchor.dy - estimatedMenuHeight > safeTop;
    final preferredTop = showAboveAnchor
        ? anchor.dy - estimatedMenuHeight + 14
        : anchor.dy - 14;
    final top = preferredTop.clamp(
      safeTop,
      maxTop < safeTop ? safeTop : maxTop,
    );
    final background = Color.lerp(
      theme.cardBackgroundColor,
      CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground.withValues(alpha: 0.94),
        context,
      ),
      0.54,
    )!;
    final border = Color.lerp(
      theme.dividerColor,
      theme.scaffoldBackgroundColor,
      0.28,
    )!
        .withValues(alpha: 0.72);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          child: SizedBox(
            width: menuWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(menuRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(menuRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: background.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(menuRadius),
                      border: Border.all(color: border, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BookContextMenuHeader(book: book, theme: theme),
                        const _BookContextMenuDivider(),
                        _BookContextMenuAction(
                          action: _BookQuickAction.details,
                          icon: CupertinoIcons.info_circle,
                          label: LocaleText.of(
                            context,
                            zh: '书籍详情',
                            en: 'Book Details',
                          ),
                          theme: theme,
                        ),
                        const _BookContextMenuDivider(),
                        _BookContextMenuAction(
                          action: _BookQuickAction.changeCover,
                          icon: CupertinoIcons.photo,
                          label: LocaleText.of(
                            context,
                            zh: '修改封面',
                            en: 'Change Cover',
                          ),
                          theme: theme,
                        ),
                        const _BookContextMenuDivider(),
                        _BookContextMenuAction(
                          action: _BookQuickAction.stats,
                          icon: CupertinoIcons.chart_bar,
                          label: LocaleText.of(
                            context,
                            zh: '阅读统计',
                            en: 'Reading Stats',
                          ),
                          theme: theme,
                        ),
                        const _BookContextMenuDivider(),
                        _BookContextMenuAction(
                          action: _BookQuickAction.delete,
                          icon: CupertinoIcons.delete,
                          label: LocaleText.of(context, zh: '删除', en: 'Delete'),
                          theme: theme,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookContextMenuHeader extends StatelessWidget {
  final Book book;
  final AppThemeData theme;

  const _BookContextMenuHeader({required this.book, required this.theme});

  @override
  Widget build(BuildContext context) {
    final author = book.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty;
    final subtitleColor = Color.lerp(
      theme.secondaryTextColor,
      theme.textColor,
      0.18,
    )!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BookCoverWidget(book: book, width: 36, height: 50),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: theme.textColor,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: 3),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                        color: subtitleColor,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookContextMenuAction extends StatelessWidget {
  final _BookQuickAction action;
  final IconData icon;
  final String label;
  final AppThemeData theme;
  final bool isDestructive;

  const _BookContextMenuAction({
    required this.action,
    required this.icon,
    required this.label,
    required this.theme,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : theme.textColor.withValues(alpha: 0.94);
    final pressedBackground = isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context).withValues(alpha: 0.08)
        : theme.primaryColor.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => Navigator.pop(context, action),
            borderRadius: BorderRadius.circular(12),
            splashColor: pressedBackground,
            highlightColor: pressedBackground,
            hoverColor: pressedBackground.withValues(alpha: 0.72),
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isDestructive
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: foreground,
                          letterSpacing: -0.1,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(icon, size: 16, color: foreground.withValues(alpha: 0.82)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookContextMenuDivider extends StatelessWidget {
  const _BookContextMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.42),
    );
  }
}

class _BookMetaRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _BookMetaRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookStatRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _BookStatRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFloatingNotice extends StatelessWidget {
  final String message;
  final AppThemeData theme;
  final _TopNoticeKind kind;
  final Animation<double> animation;
  final VoidCallback onDismiss;

  const _TopFloatingNotice({
    required this.message,
    required this.theme,
    required this.kind,
    required this.animation,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final palette = _paletteForKind();

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final slideY = Tween<double>(
                  begin: -30,
                  end: 0,
                ).evaluate(animation);
                final scale = Tween<double>(
                  begin: 0.92,
                  end: 1,
                ).evaluate(animation);
                return Opacity(
                  opacity: animation.value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, slideY),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: mediaQuery.size.width > 640 ? 356 : 332,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(26),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: palette.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: theme.textColor.withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 62),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 54,
                                  child: Center(
                                    child: Icon(
                                      palette.icon,
                                      size: 18,
                                      color: palette.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Text(
                                      message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.foreground,
                                        height: 1.24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TopNoticePalette _paletteForKind() {
    switch (kind) {
      case _TopNoticeKind.success:
        return _TopNoticePalette(
          background: Color.alphaBlend(
            theme.primaryColor.withValues(alpha: 0.2),
            theme.cardBackgroundColor,
          ),
          border: theme.primaryColor.withValues(alpha: 0.34),
          accent: theme.primaryColor,
          foreground: theme.textColor,
          icon: Icons.check_rounded,
        );
      case _TopNoticeKind.error:
        return _TopNoticePalette(
          background: Color.alphaBlend(
            const Color(0xFFD85B5B).withValues(alpha: 0.18),
            theme.cardBackgroundColor,
          ),
          border: const Color(0xFFD85B5B).withValues(alpha: 0.34),
          accent: const Color(0xFFD85B5B),
          foreground: theme.textColor,
          icon: Icons.close_rounded,
        );
      case _TopNoticeKind.info:
        return _TopNoticePalette(
          background: Color.alphaBlend(
            theme.accentColor.withValues(alpha: 0.18),
            theme.cardBackgroundColor,
          ),
          border: theme.accentColor.withValues(alpha: 0.32),
          accent: theme.accentColor,
          foreground: theme.textColor,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _TopNoticePalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color foreground;
  final IconData icon;

  const _TopNoticePalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.foreground,
    required this.icon,
  });
}
