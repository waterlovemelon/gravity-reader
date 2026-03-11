import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/category_model.dart';
import 'package:myreader/domain/entities/category.dart';

void main() {
  group('CategoryModel', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    final testCategory = Category(
      id: 'category-1',
      name: 'Fiction',
      color: 2,
      createdAt: testDate,
      sortOrder: 1,
    );

    final testMap = {
      'id': 'category-1',
      'name': 'Fiction',
      'color': 2,
      'created_at': '2024-01-01T12:00:00.000',
      'sort_order': 1,
    };

    test('should convert from Entity to Model', () {
      final model = CategoryModel.fromEntity(testCategory);

      expect(model.id, testCategory.id);
      expect(model.name, testCategory.name);
      expect(model.color, testCategory.color);
      expect(model.createdAt, testCategory.createdAt);
      expect(model.sortOrder, testCategory.sortOrder);
    });

    test('should convert from Map to Model', () {
      final model = CategoryModel.fromMap(testMap);

      expect(model.id, 'category-1');
      expect(model.name, 'Fiction');
      expect(model.color, 2);
      expect(model.sortOrder, 1);
    });

    test('should convert Model to Map', () {
      final model = CategoryModel.fromEntity(testCategory);
      final map = model.toMap();

      expect(map['id'], 'category-1');
      expect(map['name'], 'Fiction');
      expect(map['color'], 2);
      expect(map['sort_order'], 1);
    });

    test('should convert Model to Entity', () {
      final model = CategoryModel.fromMap(testMap);
      final entity = model.toEntity();

      expect(entity.id, testCategory.id);
      expect(entity.name, testCategory.name);
      expect(entity.color, testCategory.color);
    });

    test('should handle default sort order', () {
      final categoryNoSort = Category(
        id: 'category-2',
        name: 'Default',
        color: 0,
        createdAt: testDate,
        sortOrder: 0,
      );

      final model = CategoryModel.fromEntity(categoryNoSort);
      expect(model.sortOrder, 0);
    });
  });
}
