import 'package:flutter/material.dart';
import 'package:myreader/flureadium_integration/epub_parser.dart';

class TableOfContentsWidget extends StatelessWidget {
  final List<Chapter> chapters;
  final Function(Chapter)? onChapterTap;
  final int? currentChapterIndex;

  const TableOfContentsWidget({
    super.key,
    required this.chapters,
    this.onChapterTap,
    this.currentChapterIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No chapters available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final isCurrentChapter = index == currentChapterIndex;

        return ListTile(
          leading: isCurrentChapter
              ? Icon(Icons.play_arrow, color: Theme.of(context).primaryColor)
              : Text('${index + 1}', style: TextStyle(color: Colors.grey[500])),
          title: Text(
            chapter.title,
            style: TextStyle(
              fontWeight: isCurrentChapter
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isCurrentChapter ? Theme.of(context).primaryColor : null,
            ),
          ),
          trailing: isCurrentChapter
              ? Icon(
                  Icons.bookmark,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                )
              : null,
          onTap: () => onChapterTap?.call(chapter),
        );
      },
    );
  }
}
