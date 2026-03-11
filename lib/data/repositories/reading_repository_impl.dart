import 'package:myreader/data/datasources/local/reading_progress_local_data_source.dart';
import 'package:myreader/data/models/reading_progress_model.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/domain/repositories/reading_repository.dart';

class ReadingRepositoryImpl implements ReadingRepository {
  final ReadingProgressLocalDataSource _localDataSource;

  ReadingRepositoryImpl(this._localDataSource);

  @override
  Future<ReadingProgress?> getProgress(String bookId) async {
    final model = await _localDataSource.getProgress(bookId);
    return model?.toEntity();
  }

  @override
  Future<void> updateProgress(ReadingProgress progress) async {
    final model = ReadingProgressModel.fromEntity(progress);
    await _localDataSource.updateProgress(model);
  }

  @override
  Future<void> resetProgress(String bookId) async {
    await _localDataSource.resetProgress(bookId);
  }

  @override
  Future<Map<String, ReadingProgress>> getAllProgress() async {
    final models = await _localDataSource.getAllProgress();
    final Map<String, ReadingProgress> progressMap = {};
    for (final model in models) {
      final entity = model.toEntity();
      progressMap[entity.bookId] = entity;
    }
    return progressMap;
  }

  Future<void> addReadingSession({
    required String bookId,
    required DateTime startTime,
    required DateTime endTime,
    required int durationSeconds,
  }) async {
    await _localDataSource.addReadingSession(
      bookId: bookId,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSeconds,
    );
  }

  Future<List<Map<String, dynamic>>> getReadingSessions({
    String? bookId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _localDataSource.getReadingSessions(
      bookId: bookId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
