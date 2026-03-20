import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/usecases/book_usecases.dart';
import 'package:myreader/domain/usecases/note_usecases.dart';
import 'package:myreader/domain/usecases/bookmark_usecases.dart';
import 'package:myreader/domain/usecases/reading_usecases.dart';
import 'package:myreader/domain/usecases/category_usecases.dart';
import 'package:myreader/core/providers/repository_providers.dart';

final getBooksUseCaseProvider = Provider<GetBooksUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return GetBooksUseCase(repository);
});

final getBookByIdUseCaseProvider = Provider<GetBookByIdUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return GetBookByIdUseCase(repository);
});

final addBookUseCaseProvider = Provider<AddBookUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return AddBookUseCase(repository);
});

final updateBookUseCaseProvider = Provider<UpdateBookUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return UpdateBookUseCase(repository);
});

final deleteBookUseCaseProvider = Provider<DeleteBookUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return DeleteBookUseCase(repository);
});

final searchBooksUseCaseProvider = Provider<SearchBooksUseCase>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return SearchBooksUseCase(repository);
});

final getBooksByCategoryUseCaseProvider = Provider<GetBooksByCategoryUseCase>((
  ref,
) {
  final repository = ref.watch(bookRepositoryProvider);
  return GetBooksByCategoryUseCase(repository);
});

final getNotesByBookIdUseCaseProvider = Provider<GetNotesByBookIdUseCase>((
  ref,
) {
  final repository = ref.watch(noteRepositoryProvider);
  return GetNotesByBookIdUseCase(repository);
});

final saveNoteUseCaseProvider = Provider<SaveNoteUseCase>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return SaveNoteUseCase(repository);
});

final deleteNoteUseCaseProvider = Provider<DeleteNoteUseCase>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return DeleteNoteUseCase(repository);
});

final getBookmarksByBookIdUseCaseProvider =
    Provider<GetBookmarksByBookIdUseCase>((ref) {
      final repository = ref.watch(bookmarkRepositoryProvider);
      return GetBookmarksByBookIdUseCase(repository);
    });

final saveBookmarkUseCaseProvider = Provider<SaveBookmarkUseCase>((ref) {
  final repository = ref.watch(bookmarkRepositoryProvider);
  return SaveBookmarkUseCase(repository);
});

final deleteBookmarkUseCaseProvider = Provider<DeleteBookmarkUseCase>((ref) {
  final repository = ref.watch(bookmarkRepositoryProvider);
  return DeleteBookmarkUseCase(repository);
});

final getReadingProgressUseCaseProvider = Provider<GetReadingProgressUseCase>((
  ref,
) {
  final repository = ref.watch(readingRepositoryProvider);
  return GetReadingProgressUseCase(repository);
});

final getAllReadingProgressUseCaseProvider =
    Provider<GetAllReadingProgressUseCase>((ref) {
      final repository = ref.watch(readingRepositoryProvider);
      return GetAllReadingProgressUseCase(repository);
    });

final updateReadingProgressUseCaseProvider =
    Provider<UpdateReadingProgressUseCase>((ref) {
      final repository = ref.watch(readingRepositoryProvider);
      return UpdateReadingProgressUseCase(repository);
    });

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return GetCategoriesUseCase(repository);
});

final saveCategoryUseCaseProvider = Provider<SaveCategoryUseCase>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return SaveCategoryUseCase(repository);
});

final deleteCategoryUseCaseProvider = Provider<DeleteCategoryUseCase>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return DeleteCategoryUseCase(repository);
});
