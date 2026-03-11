// Category Local Data Source - Data Layer
// Handles all database operations for categories

import 'package:myreader/data/database/database_helper.dart';
import 'package:myreader/data/models/category_model.dart';

class CategoryLocalDataSource {
  final DatabaseHelper _databaseHelper;

  CategoryLocalDataSource(this._databaseHelper);

  Future<List<CategoryModel>> getCategories() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('categories', orderBy: 'sort_order ASC');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<void> insertCategory(CategoryModel category) async {
    final db = await _databaseHelper.database;
    await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _databaseHelper.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
