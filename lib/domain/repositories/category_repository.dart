import 'package:myreader/domain/entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories();
  Future<Category?> getCategoryById(String id);
  Future<void> saveCategory(Category category);
  Future<void> deleteCategory(String id);
}
