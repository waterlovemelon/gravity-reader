// Category Model - Data Layer
// Maps between Category entity and database

import 'package:myreader/domain/entities/category.dart';

class CategoryModel {
  final String id;
  final String name;
  final int color;
  final DateTime createdAt;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.sortOrder,
  });

  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      color: category.color,
      createdAt: category.createdAt,
      sortOrder: category.sortOrder,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      sortOrder: map['sort_order'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  Category toEntity() {
    return Category(
      id: id,
      name: name,
      color: color,
      createdAt: createdAt,
      sortOrder: sortOrder,
    );
  }
}
