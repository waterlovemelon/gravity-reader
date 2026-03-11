// ReadingProgress entity - Clean Architecture Domain Layer
// Represents the reading progress for a book

class ReadingProgress {
  final String bookId;
  final String location; // CFI or page location
  final double percentage; // 0.0 to 1.0
  final DateTime lastReadAt;
  final int readingTimeSeconds; // Total reading time in seconds

  ReadingProgress({
    required this.bookId,
    required this.location,
    required this.percentage,
    required this.lastReadAt,
    required this.readingTimeSeconds,
  });

  @override
  String toString() =>
      'ReadingProgress(bookId: $bookId, percentage: $percentage)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingProgress &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId;

  @override
  int get hashCode => bookId.hashCode;
}
