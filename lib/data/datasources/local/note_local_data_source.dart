// Note Local Data Source - Data Layer
// Handles all database operations for notes

import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/models/note_model.dart';

class NoteLocalDataSource {
  final DatabaseHelper _databaseHelper;

  NoteLocalDataSource(this._databaseHelper);

  Future<List<NoteModel>> getNotesByBookId(String bookId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'notes',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => NoteModel.fromMap(map)).toList();
  }

  Future<NoteModel?> getNoteById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return NoteModel.fromMap(maps.first);
  }

  Future<void> insertNote(NoteModel note) async {
    final db = await _databaseHelper.database;
    await db.insert('notes', note.toMap());
  }

  Future<void> updateNote(NoteModel note) async {
    final db = await _databaseHelper.database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NoteModel>> getAllNotes() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('notes', orderBy: 'created_at DESC');
    return maps.map((map) => NoteModel.fromMap(map)).toList();
  }
}
