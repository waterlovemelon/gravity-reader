import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_card_widget.dart';

class BookshelfGridWidget extends ConsumerWidget {
  final Function(Book)? onBookTap;
  final Function(Book)? onBookLongPress;
  final double spacing;

  const BookshelfGridWidget({
    super.key,
    this.onBookTap,
    this.onBookLongPress,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksState = ref.watch(booksProvider);

    if (booksState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (booksState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load books',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.read(booksProvider.notifier).loadBooks();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (booksState.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No books yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first book',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: booksState.books.length,
      itemBuilder: (context, index) {
        final book = booksState.books[index];
        return BookCardWidget(
          book: book,
          onTap: () => onBookTap?.call(book),
          onLongPress: () => onBookLongPress?.call(book),
        );
      },
    );
  }
}
