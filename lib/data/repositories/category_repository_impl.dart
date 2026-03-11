import 'package:myreader/data/datasources/local/category_local_data_source.dart';
import 'package:myreader/data/models/category_model.dart';
import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource _localDataSource;

  CategoryRepositoryImpl(this._localDataSource);

  @override
  Future<List<Category>> getCategories() async {
    final models = await _localDataSource.getCategories();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    final model = await _localDataSource.getCategoryById(id);
    return model?.toEntity();
  }

  @override
  Future<void> saveCategory(Category category) async {
    final model = CategoryModel.fromEntity(category);
    final existing = await _localDataSource.getCategoryById(category.id);
    if (existing != null) {
      await _localDataSource.updateCategory(model);
    } else {
      await _localDataSource.insertCategory(model);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _localDataSource.deleteCategory(id);
  }
}
