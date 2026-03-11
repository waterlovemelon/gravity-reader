import 'package:myreader/domain/entities/bookmark.dart';

abstract class BookmarkRepository {
  Future<List<Bookmark>> getBookmarksByBookId(String bookId);
  Future<Bookmark?> getBookmarkById(String id);
  Future<void> saveBookmark(Bookmark bookmark);
  Future<void> deleteBookmark(String id);
}
