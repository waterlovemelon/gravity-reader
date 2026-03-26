import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/reading_progress.dart';

class ProfileBookInsight {
  final Book book;
  final ReadingProgress? progress;
  final int noteCount;

  const ProfileBookInsight({
    required this.book,
    required this.progress,
    required this.noteCount,
  });

  int get readingTimeSeconds => progress?.readingTimeSeconds ?? 0;
  double get progressValue => progress?.percentage ?? 0.0;
  bool get isInProgress => progressValue > 0 && progressValue < 0.99;
  bool get isFinished => progressValue >= 0.99;
  bool get hasNotes => noteCount > 0;
}

class ProfileOverview {
  final int totalReadingTimeSeconds;
  final int totalNoteCount;
  final List<ProfileBookInsight> rankedBooks;
  final List<ProfileBookInsight> inProgressBooks;
  final List<ProfileBookInsight> finishedBooks;
  final List<ProfileBookInsight> notedBooks;

  const ProfileOverview({
    required this.totalReadingTimeSeconds,
    required this.totalNoteCount,
    required this.rankedBooks,
    required this.inProgressBooks,
    required this.finishedBooks,
    required this.notedBooks,
  });
}

final profileOverviewProvider = FutureProvider<ProfileOverview>((ref) async {
  final getBooks = ref.read(getBooksUseCaseProvider);
  final getAllProgress = ref.read(getAllReadingProgressUseCaseProvider);
  final getNotesByBookId = ref.read(getNotesByBookIdUseCaseProvider);

  final books = await getBooks();
  final progressMap = await getAllProgress();

  final insights = await Future.wait(
    books.map((book) async {
      final notes = await getNotesByBookId(book.id);
      return ProfileBookInsight(
        book: book,
        progress: progressMap[book.id],
        noteCount: notes.length,
      );
    }),
  );

  final rankedBooks = List<ProfileBookInsight>.from(insights)
    ..sort((a, b) {
      final readingCompare = b.readingTimeSeconds.compareTo(
        a.readingTimeSeconds,
      );
      if (readingCompare != 0) {
        return readingCompare;
      }

      final progressCompare = b.progressValue.compareTo(a.progressValue);
      if (progressCompare != 0) {
        return progressCompare;
      }

      final aDate =
          a.progress?.lastReadAt ?? a.book.lastReadAt ?? a.book.importedAt;
      final bDate =
          b.progress?.lastReadAt ?? b.book.lastReadAt ?? b.book.importedAt;
      return bDate.compareTo(aDate);
    });

  final inProgressBooks = rankedBooks
      .where((item) => item.isInProgress)
      .toList(growable: false);
  final finishedBooks = rankedBooks
      .where((item) => item.isFinished)
      .toList(growable: false);
  final notedBooks = rankedBooks
      .where((item) => item.hasNotes)
      .toList(growable: false);

  final totalReadingTimeSeconds = rankedBooks.fold<int>(
    0,
    (sum, item) => sum + item.readingTimeSeconds,
  );
  final totalNoteCount = rankedBooks.fold<int>(
    0,
    (sum, item) => sum + item.noteCount,
  );

  return ProfileOverview(
    totalReadingTimeSeconds: totalReadingTimeSeconds,
    totalNoteCount: totalNoteCount,
    rankedBooks: rankedBooks,
    inProgressBooks: inProgressBooks,
    finishedBooks: finishedBooks,
    notedBooks: notedBooks,
  );
});
