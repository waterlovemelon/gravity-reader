// Book Local Data Source - Data Layer
// Handles all database operations for books

import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/models/book_model.dart';

class BookLocalDataSource {
  final DatabaseHelper _databaseHelper;

  BookLocalDataSource(this._databaseHelper);

  Future<List<BookModel>> getBooks() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('books', orderBy: 'imported_at DESC');
    return maps.map((map) => BookModel.fromMap(map)).toList();
  }

  Future<BookModel?> getBookById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return BookModel.fromMap(maps.first);
  }

  Future<void> insertBook(BookModel book) async {
    final db = await _databaseHelper.database;
    await db.insert('books', book.toMap());
  }

  Future<void> updateBook(BookModel book) async {
    final db = await _databaseHelper.database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BookModel>> searchBooks(String query) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'books',
      where: 'title LIKE ? OR author LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'imported_at DESC',
    );
    return maps.map((map) => BookModel.fromMap(map)).toList();
  }

  Future<List<BookModel>> getBooksByCategory(String categoryId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'books',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'imported_at DESC',
    );
    return maps.map((map) => BookModel.fromMap(map)).toList();
  }
}
