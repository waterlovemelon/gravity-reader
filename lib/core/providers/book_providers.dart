import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/core/providers/usecase_providers.dart';

class BooksState {
  final List<Book> books;
  final bool isLoading;
  final String? error;
  final BookSortMode sortMode;

  const BooksState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.sortMode = BookSortMode.latestAdded,
  });

  BooksState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
    BookSortMode? sortMode,
  }) {
    return BooksState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

enum BookSortMode { latestAdded, recentRead, progress, title, author }

class BooksNotifier extends StateNotifier<BooksState> {
  final Ref _ref;

  BooksNotifier(this._ref) : super(const BooksState());

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final getBooks = _ref.read(getBooksUseCaseProvider);
      final books = await getBooks();
      final sortedBooks = await _applySort(books, state.sortMode);
      state = state.copyWith(books: sortedBooks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> searchBooks(String query) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final getBooks = _ref.read(getBooksUseCaseProvider);
      final books = await getBooks();
      final filteredBooks = _filterBooks(books, query);
      final sortedBooks = await _applySort(filteredBooks, state.sortMode);
      state = state.copyWith(books: sortedBooks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  List<Book> _filterBooks(List<Book> books, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return books;
    }

    return books
        .where((book) {
          final title = _normalizeSearchText(book.title);
          final author = _normalizeSearchText(book.author ?? '');
          final combined = _normalizeSearchText(
            '${book.title} ${book.author ?? ''}',
          );
          return _matchesQuery(title, normalizedQuery) ||
              _matchesQuery(author, normalizedQuery) ||
              _matchesQuery(combined, normalizedQuery);
        })
        .toList(growable: false);
  }

  bool _matchesQuery(String candidate, String query) {
    if (candidate.isEmpty || query.isEmpty) {
      return false;
    }
    return candidate.contains(query) || _isSubsequenceMatch(candidate, query);
  }

  bool _isSubsequenceMatch(String candidate, String query) {
    var queryIndex = 0;
    for (var i = 0; i < candidate.length; i++) {
      if (candidate[i] == query[queryIndex]) {
        queryIndex++;
        if (queryIndex == query.length) {
          return true;
        }
      }
    }
    return false;
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[\s\-_.,:;!?，。、《》“”‘’"()（）\[\]【】]+'),
      '',
    );
  }

  Future<void> setSortMode(BookSortMode mode) async {
    if (mode == state.sortMode) {
      return;
    }
    final sortedBooks = await _applySort(state.books, mode);
    state = state.copyWith(sortMode: mode, books: sortedBooks);
  }

  Future<void> deleteBook(String id) async {
    try {
      final deleteBook = _ref.read(deleteBookUseCaseProvider);
      await deleteBook(id);
      await loadBooks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addBook(Book book) async {
    try {
      final addBook = _ref.read(addBookUseCaseProvider);
      await addBook(book);
      await loadBooks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateBook(Book book) async {
    try {
      final updateBook = _ref.read(updateBookUseCaseProvider);
      await updateBook(book);
      await loadBooks();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<List<Book>> _applySort(List<Book> books, BookSortMode mode) async {
    final sorted = List<Book>.from(books);
    switch (mode) {
      case BookSortMode.latestAdded:
        sorted.sort((a, b) {
          final aPrimary = a.lastReadAt ?? a.importedAt;
          final bPrimary = b.lastReadAt ?? b.importedAt;
          final cmp = bPrimary.compareTo(aPrimary);
          if (cmp != 0) {
            return cmp;
          }
          return b.importedAt.compareTo(a.importedAt);
        });
        break;
      case BookSortMode.recentRead:
        sorted.sort((a, b) {
          final aRead = a.lastReadAt;
          final bRead = b.lastReadAt;
          if (aRead == null && bRead == null) {
            return b.importedAt.compareTo(a.importedAt);
          }
          if (aRead == null) return 1;
          if (bRead == null) return -1;
          final cmp = bRead.compareTo(aRead);
          if (cmp != 0) return cmp;
          return b.importedAt.compareTo(a.importedAt);
        });
        break;
      case BookSortMode.progress:
        final getAllProgress = _ref.read(getAllReadingProgressUseCaseProvider);
        final progressMap = await getAllProgress();
        sorted.sort((a, b) {
          final aProgress = progressMap[a.id];
          final bProgress = progressMap[b.id];
          final aPercentage = aProgress?.percentage ?? 0.0;
          final bPercentage = bProgress?.percentage ?? 0.0;
          final percentageCompare = bPercentage.compareTo(aPercentage);
          if (percentageCompare != 0) {
            return percentageCompare;
          }
          final aLastRead =
              aProgress?.lastReadAt ?? a.lastReadAt ?? a.importedAt;
          final bLastRead =
              bProgress?.lastReadAt ?? b.lastReadAt ?? b.importedAt;
          return bLastRead.compareTo(aLastRead);
        });
        break;
      case BookSortMode.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case BookSortMode.author:
        sorted.sort((a, b) => (a.author ?? '').compareTo(b.author ?? ''));
        break;
    }
    return sorted;
  }
}

final booksProvider = StateNotifierProvider<BooksNotifier, BooksState>((ref) {
  return BooksNotifier(ref);
});

final bookByIdProvider = FutureProvider.family<Book?, String>((ref, id) async {
  final getBookById = ref.watch(getBookByIdUseCaseProvider);
  return await getBookById(id);
});

final booksByCategoryProvider = FutureProvider.family<List<Book>, String>((
  ref,
  categoryId,
) async {
  final getBooksByCategory = ref.watch(getBooksByCategoryUseCaseProvider);
  return await getBooksByCategory(categoryId);
});
