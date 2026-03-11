import 'package:myreader/data/datasources/local/bookmark_local_data_source.dart';
import 'package:myreader/data/models/bookmark_model.dart';
import 'package:myreader/domain/entities/bookmark.dart';
import 'package:myreader/domain/repositories/bookmark_repository.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  final BookmarkLocalDataSource _localDataSource;

  BookmarkRepositoryImpl(this._localDataSource);

  @override
  Future<List<Bookmark>> getBookmarksByBookId(String bookId) async {
    final models = await _localDataSource.getBookmarksByBookId(bookId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Bookmark?> getBookmarkById(String id) async {
    final model = await _localDataSource.getBookmarkById(id);
    return model?.toEntity();
  }

  @override
  Future<void> saveBookmark(Bookmark bookmark) async {
    final model = BookmarkModel.fromEntity(bookmark);
    final existing = await _localDataSource.getBookmarkById(bookmark.id);
    if (existing != null) {
      await _localDataSource.updateBookmark(model);
    } else {
      await _localDataSource.insertBookmark(model);
    }
  }

  @override
  Future<void> deleteBookmark(String id) async {
    await _localDataSource.deleteBookmark(id);
  }
}
