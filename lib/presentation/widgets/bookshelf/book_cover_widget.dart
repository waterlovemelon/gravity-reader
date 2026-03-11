import 'dart:io';
import 'package:flutter/material.dart';
import 'package:myreader/domain/entities/book.dart';

class BookCoverWidget extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final String? heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.width = 120,
    this.height = 180,
    this.heroTag,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildCover(),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: heroTag == null
          ? cover
          : Hero(tag: heroTag!, transitionOnUserGestures: true, child: cover),
    );
  }

  Widget _buildCover() {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final coverFile = File(book.coverPath!);
      if (coverFile.existsSync()) {
        return Image.file(
          coverFile,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: _getPlaceholderColor(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: width * 0.3, color: Colors.white70),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              book.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.1,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (book.author != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                book.author!,
                style: TextStyle(color: Colors.white60, fontSize: width * 0.08),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPlaceholderColor() {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];
    final index = book.title.hashCode.abs() % colors.length;
    return colors[index];
  }
}
