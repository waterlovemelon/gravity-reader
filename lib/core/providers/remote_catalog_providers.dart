import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/app_constants.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/remote_catalog/remote_book_import_service.dart';
import 'package:myreader/data/services/remote_catalog/remote_catalog_api_client.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/remote_catalog/catalog_book.dart';

class RemoteCatalogState {
  final List<CatalogBookSummary> books;
  final bool isLoading;
  final String? error;
  final Set<String> importingIds;

  const RemoteCatalogState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.importingIds = const {},
  });

  RemoteCatalogState copyWith({
    List<CatalogBookSummary>? books,
    bool? isLoading,
    String? error,
    Set<String>? importingIds,
  }) {
    return RemoteCatalogState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      importingIds: importingIds ?? this.importingIds,
    );
  }
}

class RemoteCatalogNotifier extends StateNotifier<RemoteCatalogState> {
  final Ref _ref;

  RemoteCatalogNotifier(this._ref) : super(const RemoteCatalogState());

  Future<void> loadBooks({bool force = false}) async {
    if (state.books.isNotEmpty && !force) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = _ref.read(remoteCatalogApiClientProvider);
      final models = await client.fetchBooks(page: 1, pageSize: 60);
      state = state.copyWith(
        books: models.map((model) => model.toEntity()).toList(growable: false),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Book> addToLibrary(CatalogBookSummary catalogBook) async {
    if (state.importingIds.contains(catalogBook.id)) {
      throw StateError('Book is already downloading.');
    }
    state = state.copyWith(
      error: null,
      importingIds: {...state.importingIds, catalogBook.id},
    );
    try {
      final service = _ref.read(remoteBookImportServiceProvider);
      final book = await service.importFromCatalog(catalogBook);
      await _ref.read(booksProvider.notifier).addBook(book);
      return book;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      final nextImportingIds = Set<String>.from(state.importingIds)
        ..remove(catalogBook.id);
      state = state.copyWith(importingIds: nextImportingIds);
    }
  }
}

final remoteCatalogBaseUriProvider = Provider<Uri>((ref) {
  return Uri.parse(AppConstants.catalogBaseUrl);
});

final remoteCatalogApiClientProvider = Provider<RemoteCatalogApiClient>((ref) {
  return RemoteCatalogApiClient(
    baseUrl: ref.watch(remoteCatalogBaseUriProvider),
  );
});

final remoteBookImportServiceProvider = Provider<RemoteBookImportService>((
  ref,
) {
  final baseUrl = ref.watch(remoteCatalogBaseUriProvider);
  return RemoteBookImportService(
    catalogBaseUrl: baseUrl,
    epubImportCacheService: const EpubImportCacheService(),
  );
});

final remoteCatalogProvider =
    StateNotifierProvider<RemoteCatalogNotifier, RemoteCatalogState>((ref) {
      return RemoteCatalogNotifier(ref);
    });
