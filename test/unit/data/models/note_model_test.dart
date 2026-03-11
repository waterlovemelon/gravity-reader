import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/data/models/note_model.dart';
import 'package:myreader/domain/entities/note.dart';

void main() {
  group('NoteModel', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    final testNote = Note(
      id: 'note-1',
      bookId: 'book-1',
      content: 'This is a test note',
      cfi: 'epubcfi(/6/4[chapter1]!/4/2/1:0)',
      textSelection: 'Selected text',
      color: 1,
      createdAt: testDate,
      updatedAt: testDate,
    );

    final testMap = {
      'id': 'note-1',
      'book_id': 'book-1',
      'content': 'This is a test note',
      'cfi': 'epubcfi(/6/4[chapter1]!/4/2/1:0)',
      'text_selection': 'Selected text',
      'color': 1,
      'created_at': '2024-01-01T12:00:00.000',
      'updated_at': '2024-01-01T12:00:00.000',
    };

    test('should convert from Entity to Model', () {
      final model = NoteModel.fromEntity(testNote);

      expect(model.id, testNote.id);
      expect(model.bookId, testNote.bookId);
      expect(model.content, testNote.content);
      expect(model.cfi, testNote.cfi);
      expect(model.textSelection, testNote.textSelection);
      expect(model.color, testNote.color);
      expect(model.createdAt, testNote.createdAt);
      expect(model.updatedAt, testNote.updatedAt);
    });

    test('should convert from Map to Model', () {
      final model = NoteModel.fromMap(testMap);

      expect(model.id, 'note-1');
      expect(model.bookId, 'book-1');
      expect(model.content, 'This is a test note');
      expect(model.cfi, 'epubcfi(/6/4[chapter1]!/4/2/1:0)');
      expect(model.textSelection, 'Selected text');
      expect(model.color, 1);
    });

    test('should convert Model to Map', () {
      final model = NoteModel.fromEntity(testNote);
      final map = model.toMap();

      expect(map['id'], 'note-1');
      expect(map['book_id'], 'book-1');
      expect(map['content'], 'This is a test note');
      expect(map['color'], 1);
    });

    test('should convert Model to Entity', () {
      final model = NoteModel.fromMap(testMap);
      final entity = model.toEntity();

      expect(entity.id, testNote.id);
      expect(entity.bookId, testNote.bookId);
      expect(entity.content, testNote.content);
    });

    test('should handle null optional fields', () {
      final noteWithNulls = Note(
        id: 'note-2',
        bookId: 'book-1',
        content: 'Note without optionals',
        color: 0,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final model = NoteModel.fromEntity(noteWithNulls);
      final map = model.toMap();
      final entity = model.toEntity();

      expect(model.cfi, isNull);
      expect(model.textSelection, isNull);
      expect(map['cfi'], isNull);
      expect(entity.cfi, isNull);
    });
  });
}
