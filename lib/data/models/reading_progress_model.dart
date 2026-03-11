// ReadingProgress Model - Data Layer
// Maps between ReadingProgress entity and database

import 'package:myreader/domain/entities/reading_progress.dart';

class ReadingProgressModel {
  final String bookId;
  final String location;
  final double percentage;
  final DateTime lastReadAt;
  final int readingTimeSeconds;

  ReadingProgressModel({
    required this.bookId,
    required this.location,
    required this.percentage,
    required this.lastReadAt,
    required this.readingTimeSeconds,
  });

  factory ReadingProgressModel.fromEntity(ReadingProgress progress) {
    return ReadingProgressModel(
      bookId: progress.bookId,
      location: progress.location,
      percentage: progress.percentage,
      lastReadAt: progress.lastReadAt,
      readingTimeSeconds: progress.readingTimeSeconds,
    );
  }

  factory ReadingProgressModel.fromMap(Map<String, dynamic> map) {
    return ReadingProgressModel(
      bookId: map['book_id'] as String,
      location: map['location'] as String,
      percentage: (map['percentage'] as num).toDouble(),
      lastReadAt: DateTime.parse(map['last_read_at'] as String),
      readingTimeSeconds: map['reading_time_seconds'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'location': location,
      'percentage': percentage,
      'last_read_at': lastReadAt.toIso8601String(),
      'reading_time_seconds': readingTimeSeconds,
    };
  }

  ReadingProgress toEntity() {
    return ReadingProgress(
      bookId: bookId,
      location: location,
      percentage: percentage,
      lastReadAt: lastReadAt,
      readingTimeSeconds: readingTimeSeconds,
    );
  }
}
