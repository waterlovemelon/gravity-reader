import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/domain/repositories/reading_repository.dart';

class GetReadingProgressUseCase {
  final ReadingRepository _repository;

  GetReadingProgressUseCase(this._repository);

  Future<ReadingProgress?> call(String bookId) async {
    return await _repository.getProgress(bookId);
  }
}

class UpdateReadingProgressUseCase {
  final ReadingRepository _repository;

  UpdateReadingProgressUseCase(this._repository);

  Future<void> call(ReadingProgress progress) async {
    await _repository.updateProgress(progress);
  }
}

class ResetReadingProgressUseCase {
  final ReadingRepository _repository;

  ResetReadingProgressUseCase(this._repository);

  Future<void> call(String bookId) async {
    await _repository.resetProgress(bookId);
  }
}

class GetAllReadingProgressUseCase {
  final ReadingRepository _repository;

  GetAllReadingProgressUseCase(this._repository);

  Future<Map<String, ReadingProgress>> call() async {
    return await _repository.getAllProgress();
  }
}
