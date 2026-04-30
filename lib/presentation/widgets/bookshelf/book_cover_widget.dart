import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/placeholder_cover_assets.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/managed_file_paths.dart';
import 'package:myreader/domain/entities/book.dart';

class BookCoverWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.textColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BookCoverImage(book: book, width: width, height: height),
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
}

class BookCoverImage extends ConsumerWidget {
  final Book book;
  final double? width;
  final double? height;

  const BookCoverImage({
    super.key,
    required this.book,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      return FutureBuilder<File>(
        future: resolveManagedFile(book.coverPath, managedFolderName: 'covers'),
        builder: (context, snapshot) {
          final coverFile = snapshot.data;
          if (coverFile != null && coverFile.existsSync()) {
            return Image.file(
              coverFile,
              fit: BoxFit.cover,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) =>
                  _buildPlaceholder(context, ref),
            );
          }
          return _buildPlaceholder(context, ref);
        },
      );
    }
    return _buildPlaceholder(context, ref);
  }

  Widget _buildPlaceholder(BuildContext context, WidgetRef ref) {
    final assetPath =
        placeholderCoverAssets[book.id.hashCode.abs() %
            placeholderCoverAssets.length];
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [Color(0xFFE8F0E7), Color(0xFFADC4A7)],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFF9C27B0), // Purple for books/reading
            size: 28,
          ),
        ),
      ),
    );
  }
}
