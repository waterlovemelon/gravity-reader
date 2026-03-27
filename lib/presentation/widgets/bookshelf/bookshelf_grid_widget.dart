import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_card_widget.dart';

class BookshelfGridWidget extends ConsumerWidget {
  final List<Book> books;
  final Map<String, ReadingProgress> progressByBookId;
  final Set<String> selectedBookIds;
  final bool selectionMode;
  final Function(Book)? onBookTap;
  final Function(Book, Offset)? onBookMenuRequest;
  final double spacing;

  const BookshelfGridWidget({
    super.key,
    required this.books,
    required this.progressByBookId,
    required this.selectedBookIds,
    required this.selectionMode,
    this.onBookTap,
    this.onBookMenuRequest,
    this.spacing = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    if (books.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: const Color(0xFF9C27B0), // Purple for books/library
              ),
              const SizedBox(height: 16),
              Text(
                LocaleText.of(context, zh: '还没有书籍', en: 'No books yet'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LocaleText.of(
                  context,
                  zh: '点击右上角 + 导入第一本书',
                  en: 'Tap + to add your first book',
                ),
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(spacing, 0, spacing, spacing + 80),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final book = books[index];
          return BookCardWidget(
            book: book,
            progress: progressByBookId[book.id]?.percentage,
            isSelected: selectedBookIds.contains(book.id),
            selectionMode: selectionMode,
            onTap: () => onBookTap?.call(book),
            onLongPressStart: selectionMode
                ? null
                : (details) =>
                      onBookMenuRequest?.call(book, details.globalPosition),
            onSecondaryTapDown: selectionMode
                ? null
                : (details) =>
                      onBookMenuRequest?.call(book, details.globalPosition),
          );
        }, childCount: books.length),
      ),
    );
  }
}
