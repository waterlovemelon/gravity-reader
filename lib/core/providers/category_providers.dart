import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/category.dart';
import 'package:myreader/core/providers/usecase_providers.dart';

class CategoriesState {
  final List<Category> categories;
  final bool isLoading;
  final String? error;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<Category>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final Ref _ref;

  CategoriesNotifier(this._ref) : super(const CategoriesState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final getCategories = _ref.read(getCategoriesUseCaseProvider);
      final categories = await getCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveCategory(Category category) async {
    try {
      final saveCategory = _ref.read(saveCategoryUseCaseProvider);
      await saveCategory(category);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final deleteCategory = _ref.read(deleteCategoryUseCaseProvider);
      await deleteCategory(id);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
      return CategoriesNotifier(ref);
    });
