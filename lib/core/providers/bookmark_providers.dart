import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/bookmark.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/core/providers/usecase_providers.dart';

class BookmarksState {
  final List<Bookmark> bookmarks;
  final bool isLoading;
  final String? error;

  const BookmarksState({
    this.bookmarks = const [],
    this.isLoading = false,
    this.error,
  });

  BookmarksState copyWith({
    List<Bookmark>? bookmarks,
    bool? isLoading,
    String? error,
  }) {
    return BookmarksState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BookmarksNotifier extends StateNotifier<BookmarksState> {
  final Ref _ref;
  final String bookId;

  BookmarksNotifier(this._ref, this.bookId) : super(const BookmarksState());

  Future<void> loadBookmarks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final getBookmarks = _ref.read(getBookmarksByBookIdUseCaseProvider);
      final bookmarks = await getBookmarks(bookId);
      state = state.copyWith(bookmarks: bookmarks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveBookmark(Bookmark bookmark) async {
    try {
      final saveBookmark = _ref.read(saveBookmarkUseCaseProvider);
      await saveBookmark(bookmark);
      await loadBookmarks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteBookmark(String id) async {
    try {
      final deleteBookmark = _ref.read(deleteBookmarkUseCaseProvider);
      await deleteBookmark(id);
      await loadBookmarks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final bookmarksProvider =
    StateNotifierProvider.family<BookmarksNotifier, BookmarksState, String>((
      ref,
      bookId,
    ) {
      return BookmarksNotifier(ref, bookId);
    });

class ReadingProgressNotifier extends StateNotifier<ReadingProgress?> {
  final Ref _ref;
  final String bookId;

  ReadingProgressNotifier(this._ref, this.bookId) : super(null);

  Future<void> loadProgress() async {
    try {
      final getProgress = _ref.read(getReadingProgressUseCaseProvider);
      final progress = await getProgress(bookId);
      state = progress;
    } catch (e) {
      state = null;
    }
  }

  Future<void> updateProgress(ReadingProgress progress) async {
    try {
      final updateProgress = _ref.read(updateReadingProgressUseCaseProvider);
      await updateProgress(progress);
      state = progress;
    } catch (e) {
      // Handle error
    }
  }
}

final readingProgressProvider =
    StateNotifierProvider.family<
      ReadingProgressNotifier,
      ReadingProgress?,
      String
    >((ref, bookId) {
      return ReadingProgressNotifier(ref, bookId);
    });
