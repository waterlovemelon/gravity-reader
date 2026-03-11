// Category entity - Clean Architecture Domain Layer
// Represents a book category for organizing books

class Category {
  final String id;
  final String name;
  final int color; // Color index for category icon
  final DateTime createdAt;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.sortOrder,
  });

  @override
  String toString() => 'Category(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
