// SQLite Database Helper - Clean Architecture Data Layer
// Handles database initialization, migrations, and provides database access

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myreader/core/constants/app_constants.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create books table
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        cover_path TEXT,
        epub_path TEXT NOT NULL,
        total_pages INTEGER,
        file_size INTEGER NOT NULL,
        imported_at TEXT NOT NULL,
        last_read_at TEXT,
        category_id TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT,
        text_selection TEXT,
        color INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // Create bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        cfi TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // Create reading_progress table
    await db.execute('''
      CREATE TABLE reading_progress (
        book_id TEXT PRIMARY KEY,
        location TEXT NOT NULL,
        percentage REAL NOT NULL DEFAULT 0.0,
        last_read_at TEXT NOT NULL,
        reading_time_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create reading_statistics table for tracking reading time
    await db.execute('''
      CREATE TABLE reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_books_category ON books(category_id)');
    await db.execute('CREATE INDEX idx_books_title ON books(title)');
    await db.execute('CREATE INDEX idx_notes_book ON notes(book_id)');
    await db.execute('CREATE INDEX idx_bookmarks_book ON bookmarks(book_id)');
    await db.execute(
      'CREATE INDEX idx_sessions_book ON reading_sessions(book_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration for cover_path support
      // Check if cover_path column exists in books table
      final columns = await db.rawQuery("PRAGMA table_info(books)");
      final hasCoverPath = columns.any(
        (column) => column['name'] == 'cover_path',
      );

      if (!hasCoverPath) {
        print('Migrating database: Adding cover_path column to books table');
        await db.execute('ALTER TABLE books ADD COLUMN cover_path TEXT');
        print('Migration successful: cover_path column added');
      } else {
        print('Migration skipped: cover_path column already exists');
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
