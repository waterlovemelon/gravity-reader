import 'package:myreader/domain/entities/note.dart';
import 'package:myreader/domain/repositories/note_repository.dart';

class GetNotesByBookIdUseCase {
  final NoteRepository _repository;

  GetNotesByBookIdUseCase(this._repository);

  Future<List<Note>> call(String bookId) async {
    return await _repository.getNotesByBookId(bookId);
  }
}

class GetNoteByIdUseCase {
  final NoteRepository _repository;

  GetNoteByIdUseCase(this._repository);

  Future<Note?> call(String id) async {
    return await _repository.getNoteById(id);
  }
}

class SaveNoteUseCase {
  final NoteRepository _repository;

  SaveNoteUseCase(this._repository);

  Future<void> call(Note note) async {
    await _repository.saveNote(note);
  }
}

class DeleteNoteUseCase {
  final NoteRepository _repository;

  DeleteNoteUseCase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteNote(id);
  }
}
