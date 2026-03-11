import 'package:myreader/domain/entities/reading_progress.dart';

abstract class ReadingRepository {
  Future<ReadingProgress?> getProgress(String bookId);
  Future<void> updateProgress(ReadingProgress progress);
  Future<void> resetProgress(String bookId);
  Future<Map<String, ReadingProgress>> getAllProgress();
}
