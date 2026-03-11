import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/domain/repositories/category_repository.dart';

class GetCategoriesUseCase {
  final CategoryRepository _repository;

  GetCategoriesUseCase(this._repository);

  Future<List<Category>> call() async {
    return await _repository.getCategories();
  }
}

class GetCategoryByIdUseCase {
  final CategoryRepository _repository;

  GetCategoryByIdUseCase(this._repository);

  Future<Category?> call(String id) async {
    return await _repository.getCategoryById(id);
  }
}

class SaveCategoryUseCase {
  final CategoryRepository _repository;

  SaveCategoryUseCase(this._repository);

  Future<void> call(Category category) async {
    await _repository.saveCategory(category);
  }
}

class DeleteCategoryUseCase {
  final CategoryRepository _repository;

  DeleteCategoryUseCase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteCategory(id);
  }
}
