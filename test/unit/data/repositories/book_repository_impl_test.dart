import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myreader/data/datasources/local/book_local_data_source.dart';
import 'package:myreader/data/models/book_model.dart';
import 'package:myreader/data/repositories/book_repository_impl.dart';
import 'package:myreader/domain/entities/book.dart';
import '../../../test_utils/mock_repositories.dart';
import '../../../test_utils/sample_data.dart';

class MockBookLocalDataSource extends Mock implements BookLocalDataSource {}

void main() {
  late BookRepositoryImpl repository;
  late MockBookLocalDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockBookLocalDataSource();
    repository = BookRepositoryImpl(mockDataSource);
    registerFallbackValues();
  });

  group('BookRepositoryImpl', () {
    test('getBooks should return list of books', () async {
      final models = [
        BookModel.fromEntity(SampleData.sampleBook),
        BookModel.fromEntity(SampleData.sampleBooks[1]),
      ];
      when(() => mockDataSource.getBooks()).thenAnswer((_) async => models);

      final result = await repository.getBooks();

      expect(result.length, 2);
      expect(result[0].id, 'book-1');
      expect(result[1].id, 'book-2');
      verify(() => mockDataSource.getBooks()).called(1);
    });

    test('getBookById should return book when found', () async {
      final model = BookModel.fromEntity(SampleData.sampleBook);
      when(
        () => mockDataSource.getBookById('book-1'),
      ).thenAnswer((_) async => model);

      final result = await repository.getBookById('book-1');

      expect(result, isNotNull);
      expect(result!.id, 'book-1');
      expect(result.title, 'Sample Book');
    });

    test('getBookById should return null when not found', () async {
      when(
        () => mockDataSource.getBookById('nonexistent'),
      ).thenAnswer((_) async => null);

      final result = await repository.getBookById('nonexistent');

      expect(result, isNull);
    });

    test('addBook should insert book into database', () async {
      when(() => mockDataSource.insertBook(any())).thenAnswer((_) async => {});

      await repository.addBook(SampleData.sampleBook);

      verify(() => mockDataSource.insertBook(any())).called(1);
    });

    test('updateBook should update book in database', () async {
      when(() => mockDataSource.updateBook(any())).thenAnswer((_) async => {});

      await repository.updateBook(SampleData.sampleBook);

      verify(() => mockDataSource.updateBook(any())).called(1);
    });

    test('deleteBook should delete book from database', () async {
      when(
        () => mockDataSource.deleteBook('book-1'),
      ).thenAnswer((_) async => {});

      await repository.deleteBook('book-1');

      verify(() => mockDataSource.deleteBook('book-1')).called(1);
    });

    test('searchBooks should return matching books', () async {
      final models = [BookModel.fromEntity(SampleData.sampleBook)];
      when(
        () => mockDataSource.searchBooks('Sample'),
      ).thenAnswer((_) async => models);

      final result = await repository.searchBooks('Sample');

      expect(result.length, 1);
      expect(result[0].title, 'Sample Book');
    });

    test('getBooksByCategory should return books in category', () async {
      final models = [BookModel.fromEntity(SampleData.sampleBook)];
      when(
        () => mockDataSource.getBooksByCategory('category-1'),
      ).thenAnswer((_) async => models);

      final result = await repository.getBooksByCategory('category-1');

      expect(result.length, 1);
      expect(result[0].categoryId, 'category-1');
    });
  });
}
