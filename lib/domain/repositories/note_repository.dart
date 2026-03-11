import 'package:myreader/domain/entities/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotesByBookId(String bookId);
  Future<Note?> getNoteById(String id);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
}
