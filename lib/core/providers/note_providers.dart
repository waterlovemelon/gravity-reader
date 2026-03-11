import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/note.dart';
import 'package:myreader/core/providers/usecase_providers.dart';

class NotesState {
  final List<Note> notes;
  final bool isLoading;
  final String? error;

  const NotesState({this.notes = const [], this.isLoading = false, this.error});

  NotesState copyWith({List<Note>? notes, bool? isLoading, String? error}) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  final Ref _ref;
  final String bookId;

  NotesNotifier(this._ref, this.bookId) : super(const NotesState());

  Future<void> loadNotes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final getNotes = _ref.read(getNotesByBookIdUseCaseProvider);
      final notes = await getNotes(bookId);
      state = state.copyWith(notes: notes, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveNote(Note note) async {
    try {
      final saveNote = _ref.read(saveNoteUseCaseProvider);
      await saveNote(note);
      await loadNotes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final deleteNote = _ref.read(deleteNoteUseCaseProvider);
      await deleteNote(id);
      await loadNotes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final notesProvider =
    StateNotifierProvider.family<NotesNotifier, NotesState, String>((
      ref,
      bookId,
    ) {
      return NotesNotifier(ref, bookId);
    });
