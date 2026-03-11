// Bookmark Local Data Source - Data Layer
// Handles all database operations for bookmarks

import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/models/bookmark_model.dart';

class BookmarkLocalDataSource {
  final DatabaseHelper _databaseHelper;

  BookmarkLocalDataSource(this._databaseHelper);

  Future<List<BookmarkModel>> getBookmarksByBookId(String bookId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => BookmarkModel.fromMap(map)).toList();
  }

  Future<BookmarkModel?> getBookmarkById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query('bookmarks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return BookmarkModel.fromMap(maps.first);
  }

  Future<void> insertBookmark(BookmarkModel bookmark) async {
    final db = await _databaseHelper.database;
    await db.insert('bookmarks', bookmark.toMap());
  }

  Future<void> updateBookmark(BookmarkModel bookmark) async {
    final db = await _databaseHelper.database;
    await db.update(
      'bookmarks',
      bookmark.toMap(),
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  Future<void> deleteBookmark(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BookmarkModel>> getAllBookmarks() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('bookmarks', orderBy: 'created_at DESC');
    return maps.map((map) => BookmarkModel.fromMap(map)).toList();
  }
}
