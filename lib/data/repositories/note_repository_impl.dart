import 'package:myreader/data/datasources/local/note_local_data_source.dart';
import 'package:myreader/data/models/note_model.dart';
import 'package:myreader/domain/entities/note.dart';
import 'package:myreader/domain/repositories/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  final NoteLocalDataSource _localDataSource;

  NoteRepositoryImpl(this._localDataSource);

  @override
  Future<List<Note>> getNotesByBookId(String bookId) async {
    final models = await _localDataSource.getNotesByBookId(bookId);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final model = await _localDataSource.getNoteById(id);
    return model?.toEntity();
  }

  @override
  Future<void> saveNote(Note note) async {
    final model = NoteModel.fromEntity(note);
    final existing = await _localDataSource.getNoteById(note.id);
    if (existing != null) {
      await _localDataSource.updateNote(model);
    } else {
      await _localDataSource.insertNote(model);
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    await _localDataSource.deleteNote(id);
  }
}
