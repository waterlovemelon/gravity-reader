import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/repositories/book_repository.dart';
import 'package:myreader/domain/usecases/book_usecases.dart';
import '../../../test_utils/mock_repositories.dart';
import '../../../test_utils/sample_data.dart';

void main() {
  late MockBookRepository mockRepository;

  setUp(() {
    mockRepository = MockBookRepository();
    registerFallbackValues();
  });

  group('GetBooksUseCase', () {
    test('should return list of books from repository', () async {
      when(
        () => mockRepository.getBooks(),
      ).thenAnswer((_) async => SampleData.sampleBooks);

      final useCase = GetBooksUseCase(mockRepository);
      final result = await useCase();

      expect(result, SampleData.sampleBooks);
      verify(() => mockRepository.getBooks()).called(1);
    });
  });

  group('GetBookByIdUseCase', () {
    test('should return book when found', () async {
      when(
        () => mockRepository.getBookById('book-1'),
      ).thenAnswer((_) async => SampleData.sampleBook);

      final useCase = GetBookByIdUseCase(mockRepository);
      final result = await useCase('book-1');

      expect(result, SampleData.sampleBook);
      verify(() => mockRepository.getBookById('book-1')).called(1);
    });

    test('should return null when not found', () async {
      when(
        () => mockRepository.getBookById('nonexistent'),
      ).thenAnswer((_) async => null);

      final useCase = GetBookByIdUseCase(mockRepository);
      final result = await useCase('nonexistent');

      expect(result, isNull);
    });
  });

  group('AddBookUseCase', () {
    test('should call repository addBook', () async {
      when(() => mockRepository.addBook(any())).thenAnswer((_) async => {});

      final useCase = AddBookUseCase(mockRepository);
      await useCase(SampleData.sampleBook);

      verify(() => mockRepository.addBook(any())).called(1);
    });
  });

  group('UpdateBookUseCase', () {
    test('should call repository updateBook', () async {
      when(() => mockRepository.updateBook(any())).thenAnswer((_) async => {});

      final useCase = UpdateBookUseCase(mockRepository);
      await useCase(SampleData.sampleBook);

      verify(() => mockRepository.updateBook(any())).called(1);
    });
  });

  group('DeleteBookUseCase', () {
    test('should call repository deleteBook', () async {
      when(
        () => mockRepository.deleteBook('book-1'),
      ).thenAnswer((_) async => {});

      final useCase = DeleteBookUseCase(mockRepository);
      await useCase('book-1');

      verify(() => mockRepository.deleteBook('book-1')).called(1);
    });
  });

  group('SearchBooksUseCase', () {
    test('should return matching books', () async {
      when(
        () => mockRepository.searchBooks('Sample'),
      ).thenAnswer((_) async => [SampleData.sampleBook]);

      final useCase = SearchBooksUseCase(mockRepository);
      final result = await useCase('Sample');

      expect(result.length, 1);
      expect(result[0].title, 'Sample Book');
    });
  });

  group('GetBooksByCategoryUseCase', () {
    test('should return books in category', () async {
      when(
        () => mockRepository.getBooksByCategory('category-1'),
      ).thenAnswer((_) async => [SampleData.sampleBook]);

      final useCase = GetBooksByCategoryUseCase(mockRepository);
      final result = await useCase('category-1');

      expect(result.length, 1);
      expect(result[0].categoryId, 'category-1');
    });
  });
}
