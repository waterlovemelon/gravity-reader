import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myreader/core/constants/placeholder_cover_assets.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/bookmark_providers.dart';
import 'package:myreader/core/providers/category_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/data/services/txt_import_cache_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/flureadium_integration/epub_parser.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:myreader/presentation/widgets/bookshelf/bookshelf_grid_widget.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  final TextEditingController _searchController = TextEditingController();
  final TxtImportCacheService _txtImportCacheService =
      const TxtImportCacheService();
  bool _isSearching = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = <String>{};

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
                decoration: const InputDecoration(
                  hintText: '搜索书名',
                  border: InputBorder.none,
                ),
                onChanged: _handleSearchChanged,
              )
            : const Text(
                '书架',
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
              _isSelectionMode ? '完成' : '编辑',
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
                              _isSearching ? '搜索结果' : '全部书籍',
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
                                    allVisibleSelected ? '取消全选' : '全选',
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
                              'Failed to load books',
                              style: TextStyle(color: theme.secondaryTextColor),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _refreshShelf,
                              child: const Text('Retry'),
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
                    onBookLongPress: _handleBookLongPress,
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

  void _handleBookLongPress(Book book) {
    if (_isSelectionMode) {
      _toggleBookSelection(book.id);
      return;
    }
    setState(() {
      _isSelectionMode = true;
      _selectedBookIds.add(book.id);
    });
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
        title: const Text('批量删除'),
        content: Text('确认删除已选的 $count 本书吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
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
                title: const Text(
                  '排序方式',
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
              const ListTile(
                title: Text(
                  '移动到分类',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('新建分类'),
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
                title: const Text('未分类'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(categoryId == null ? '已移出分类' : '已更新书籍分类')),
    );
  }

  Future<void> _createCategoryAndMoveSelected() async {
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '输入分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.pop(context, name);
            },
            child: const Text('创建'),
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
    return '按${_sortMenuLabel(mode)}';
  }

  String _sortMenuLabel(BookSortMode mode) {
    switch (mode) {
      case BookSortMode.latestAdded:
        return '最近导入';
      case BookSortMode.recentRead:
        return '最近阅读';
      case BookSortMode.progress:
        return '阅读进度';
      case BookSortMode.title:
        return '书名';
      case BookSortMode.author:
        return '作者';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除书籍失败: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an EPUB or TXT file')),
        );
        return;
      }

      if (pickedFile.path == null) return;

      // Show loading
      if (!mounted) return;
      _showLoadingDialog('Importing book...');

      // Copy file to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.${fileExt}';
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported: ${book.title}')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.cardBackgroundColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.textColor.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: AspectRatio(
                    aspectRatio: 0.72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _CurrentlyReadingCover(book: book),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            fontSize: 19,
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
                              : '未知作者',
                          style: TextStyle(
                            fontSize: 12.5,
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
                                '阅读进度',
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
                                color: theme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '正在阅读',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonal(
                              onPressed: onListenTap,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(82, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('听书'),
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

class _CurrentlyReadingCover extends StatelessWidget {
  final Book book;

  const _CurrentlyReadingCover({required this.book});

  @override
  Widget build(BuildContext context) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    final colors = [
      const Color(0xFFDCE7D8),
      const Color(0xFFD7E5EC),
      const Color(0xFFE8DED4),
    ];
    final color = colors[book.title.hashCode.abs() % colors.length];
    return Container(
      color: color,
      padding: const EdgeInsets.all(14),
      alignment: Alignment.centerLeft,
      child: Text(
        book.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: Color(0xFF203126),
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
                '已选 $selectedCount 本',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '可批量删除',
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
                child: const Text('分类'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: onDelete, child: const Text('删除')),
            ],
          ),
        ),
      ),
    );
  }
}
