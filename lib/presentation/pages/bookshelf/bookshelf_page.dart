import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/data/services/txt_parser.dart';
import 'package:myreader/domain/entities/book.dart';
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
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(booksProvider.notifier).loadBooks();
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书名',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    ref.read(booksProvider.notifier).searchBooks(value);
                  } else {
                    ref.read(booksProvider.notifier).loadBooks();
                  }
                },
              )
            : Builder(
                builder: (context) {
                  final theme = ref.watch(currentThemeProvider);
                  return Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: theme.secondaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '史上最强炼气期',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(booksProvider.notifier).loadBooks();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '书架',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _importBook,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18),
                        SizedBox(width: 4),
                        Text('导入'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 32,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _ShelfTab(label: '默认', selected: true),
                  _ShelfTab(label: '更新(1)'),
                  _ShelfTab(label: '进度'),
                  _ShelfTab(label: '推荐值'),
                  _ShelfTab(label: '书名'),
                  _ShelfTab(label: '分类'),
                ],
              ),
            ),
          ),
          Expanded(
            child: BookshelfGridWidget(
              onBookTap: (book) {
                _openReader(book);
              },
              onBookLongPress: (book) {
                _showBookOptions(context, book.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBookOptions(BuildContext context, String bookId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Book Details'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('设置封面'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpdateCover(bookId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(bookId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String bookId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(booksProvider.notifier).deleteBook(bookId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpdateCover(String bookId) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      // Get the book
      final book = ref
          .read(booksProvider)
          .books
          .firstWhere((b) => b.id == bookId);

      // Save image to app document directory
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Use the original file extension from the image path
      final imagePath = image.path;
      final fileExtension = imagePath.contains('.')
          ? imagePath.split('.').last.toLowerCase()
          : 'jpg';
      final coverFileName = '${book.id}.$fileExtension';
      final coverFilePath = '${coversDir.path}/$coverFileName';
      final previousCoverPath = book.coverPath;

      // Convert XFile to File and copy to covers directory
      final sourceFile = File(imagePath);
      await sourceFile.copy(coverFilePath);
      if (previousCoverPath != null && previousCoverPath.isNotEmpty) {
        await FileImage(File(previousCoverPath)).evict();
      }
      await FileImage(File(coverFilePath)).evict();

      // Update book with new cover path
      final updatedBook = Book(
        id: book.id,
        title: book.title,
        author: book.author,
        coverPath: coverFilePath,
        epubPath: book.epubPath,
        totalPages: book.totalPages,
        fileSize: book.fileSize,
        importedAt: book.importedAt,
        lastReadAt: book.lastReadAt,
        categoryId: book.categoryId,
      );

      // Update book in database
      final updateBookUseCase = ref.read(updateBookUseCaseProvider);
      await updateBookUseCase(updatedBook);

      // Reload books to refresh UI
      await ref.read(booksProvider.notifier).loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('封面已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新封面失败: $e')));
      }
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
        final rawText = await _readTxtContent(newPath);
        final txtResult = TxtParser().parse(rawText);
        title = baseTitle;
        totalPages = txtResult.chapters.isEmpty ? 1 : txtResult.chapters.length;
      }

      // Create book entity
      final book = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            ReaderPage(bookId: book.id, initialBook: book),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await ref.read(booksProvider.notifier).loadBooks();
  }

  Future<String> _readTxtContent(String path) async {
    final bytes = await File(path).readAsBytes();

    // Prefer UTF-8, fallback to common Chinese encodings (GB18030/GBK), then tolerant decode.
    try {
      return utf8.decode(bytes);
    } catch (_) {
      final gb18030Text = await CharsetConverter.decode('gb18030', bytes);
      if (_containsReadableCjk(gb18030Text)) {
        return gb18030Text;
      }

      final gbkText = await CharsetConverter.decode('gbk', bytes);
      if (_containsReadableCjk(gbkText)) {
        return gbkText;
      }

      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (utf8Text.trim().isNotEmpty) {
        return utf8Text;
      }

      final latinText = latin1.decode(bytes, allowInvalid: true);
      if (latinText.trim().isNotEmpty) {
        return latinText;
      }

      if (gb18030Text.trim().isNotEmpty) {
        return gb18030Text;
      }
      if (gbkText.trim().isNotEmpty) {
        return gbkText;
      }
      return utf8Text;
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
}

class _ShelfTab extends ConsumerWidget {
  final String label;
  final bool selected;

  const _ShelfTab({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: selected ? theme.primaryColor : theme.secondaryTextColor,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
