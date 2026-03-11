import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/reading_progress_model.dart';
import 'package:myreader/domain/entities/reading_progress.dart';

void main() {
  group('ReadingProgressModel', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    final testProgress = ReadingProgress(
      bookId: 'book-1',
      location: 'epubcfi(/6/4[chapter5]!/4/2/1:50)',
      percentage: 0.45,
      lastReadAt: testDate,
      readingTimeSeconds: 3600,
    );

    final testMap = {
      'book_id': 'book-1',
      'location': 'epubcfi(/6/4[chapter5]!/4/2/1:50)',
      'percentage': 0.45,
      'last_read_at': '2024-01-01T12:00:00.000',
      'reading_time_seconds': 3600,
    };

    test('should convert from Entity to Model', () {
      final model = ReadingProgressModel.fromEntity(testProgress);

      expect(model.bookId, testProgress.bookId);
      expect(model.location, testProgress.location);
      expect(model.percentage, testProgress.percentage);
      expect(model.lastReadAt, testProgress.lastReadAt);
      expect(model.readingTimeSeconds, testProgress.readingTimeSeconds);
    });

    test('should convert from Map to Model', () {
      final model = ReadingProgressModel.fromMap(testMap);

      expect(model.bookId, 'book-1');
      expect(model.location, 'epubcfi(/6/4[chapter5]!/4/2/1:50)');
      expect(model.percentage, 0.45);
      expect(model.readingTimeSeconds, 3600);
    });

    test('should convert Model to Map', () {
      final model = ReadingProgressModel.fromEntity(testProgress);
      final map = model.toMap();

      expect(map['book_id'], 'book-1');
      expect(map['location'], 'epubcfi(/6/4[chapter5]!/4/2/1:50)');
      expect(map['percentage'], 0.45);
      expect(map['reading_time_seconds'], 3600);
    });

    test('should convert Model to Entity', () {
      final model = ReadingProgressModel.fromMap(testMap);
      final entity = model.toEntity();

      expect(entity.bookId, testProgress.bookId);
      expect(entity.location, testProgress.location);
      expect(entity.percentage, testProgress.percentage);
    });

    test('should handle integer percentage from database', () {
      final mapWithInt = {
        'book_id': 'book-1',
        'location': 'location',
        'percentage': 0,
        'last_read_at': '2024-01-01T12:00:00.000',
        'reading_time_seconds': 0,
      };

      final model = ReadingProgressModel.fromMap(mapWithInt);
      expect(model.percentage, 0.0);
    });
  });
}
