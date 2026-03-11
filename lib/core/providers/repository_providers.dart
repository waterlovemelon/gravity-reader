import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/datasources/local/book_local_data_source.dart';
import 'package:myreader/data/datasources/local/note_local_data_source.dart';
import 'package:myreader/data/datasources/local/bookmark_local_data_source.dart';
import 'package:myreader/data/datasources/local/reading_progress_local_data_source.dart';
import 'package:myreader/data/datasources/local/category_local_data_source.dart';
import 'package:myreader/data/repositories/book_repository_impl.dart';
import 'package:myreader/data/repositories/note_repository_impl.dart';
import 'package:myreader/data/repositories/bookmark_repository_impl.dart';
import 'package:myreader/data/repositories/reading_repository_impl.dart';
import 'package:myreader/data/repositories/category_repository_impl.dart';
import 'package:myreader/domain/repositories/book_repository.dart';
import 'package:myreader/domain/repositories/note_repository.dart';
import 'package:myreader/domain/repositories/bookmark_repository.dart';
import 'package:myreader/domain/repositories/reading_repository.dart';
import 'package:myreader/domain/repositories/category_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final bookLocalDataSourceProvider = Provider<BookLocalDataSource>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return BookLocalDataSource(dbHelper);
});

final noteLocalDataSourceProvider = Provider<NoteLocalDataSource>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return NoteLocalDataSource(dbHelper);
});

final bookmarkLocalDataSourceProvider = Provider<BookmarkLocalDataSource>((
  ref,
) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return BookmarkLocalDataSource(dbHelper);
});

final readingProgressLocalDataSourceProvider =
    Provider<ReadingProgressLocalDataSource>((ref) {
      final dbHelper = ref.watch(databaseHelperProvider);
      return ReadingProgressLocalDataSource(dbHelper);
    });

final categoryLocalDataSourceProvider = Provider<CategoryLocalDataSource>((
  ref,
) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return CategoryLocalDataSource(dbHelper);
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final dataSource = ref.watch(bookLocalDataSourceProvider);
  return BookRepositoryImpl(dataSource);
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final dataSource = ref.watch(noteLocalDataSourceProvider);
  return NoteRepositoryImpl(dataSource);
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final dataSource = ref.watch(bookmarkLocalDataSourceProvider);
  return BookmarkRepositoryImpl(dataSource);
});

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final dataSource = ref.watch(readingProgressLocalDataSourceProvider);
  return ReadingRepositoryImpl(dataSource);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dataSource = ref.watch(categoryLocalDataSourceProvider);
  return CategoryRepositoryImpl(dataSource);
});
