import 'package:flutter/material.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

class BookCardWidget extends StatelessWidget {
  final Book book;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCardWidget({
    super.key,
    required this.book,
    this.progress,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final infoHeight = progress != null
            ? 70.0
            : (book.author != null ? 58.0 : 48.0);
        final coverHeight = (constraints.maxHeight - infoHeight - 8).clamp(
          80.0,
          220.0,
        );

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCoverWidget(
                book: book,
                width: constraints.maxWidth,
                height: coverHeight,
                heroTag: 'book-cover-${book.id}',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress!,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
