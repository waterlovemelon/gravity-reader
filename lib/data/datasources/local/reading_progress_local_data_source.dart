// Reading Progress Local Data Source - Data Layer
// Handles all database operations for reading progress

import 'package:sqflite/sqflite.dart';
import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/models/reading_progress_model.dart';

class ReadingProgressLocalDataSource {
  final DatabaseHelper _databaseHelper;

  ReadingProgressLocalDataSource(this._databaseHelper);

  Future<ReadingProgressModel?> getProgress(String bookId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return ReadingProgressModel.fromMap(maps.first);
  }

  Future<void> updateProgress(ReadingProgressModel progress) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'reading_progress',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'books',
        {'last_read_at': progress.lastReadAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [progress.bookId],
      );
    });
  }

  Future<void> resetProgress(String bookId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<ReadingProgressModel>> getAllProgress() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('reading_progress');
    return maps.map((map) => ReadingProgressModel.fromMap(map)).toList();
  }

  // Reading sessions for statistics
  Future<void> addReadingSession({
    required String bookId,
    required DateTime startTime,
    required DateTime endTime,
    required int durationSeconds,
  }) async {
    final db = await _databaseHelper.database;
    await db.insert('reading_sessions', {
      'book_id': bookId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': durationSeconds,
    });
  }

  Future<List<Map<String, dynamic>>> getReadingSessions({
    String? bookId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _databaseHelper.database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (bookId != null) {
      where = 'book_id = ?';
      whereArgs.add(bookId);
    }

    if (startDate != null) {
      where += where.isEmpty ? 'start_time >= ?' : ' AND start_time >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += where.isEmpty ? 'start_time <= ?' : ' AND start_time <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    return await db.query(
      'reading_sessions',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'start_time DESC',
    );
  }
}
