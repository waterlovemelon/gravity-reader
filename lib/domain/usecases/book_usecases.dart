import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/repositories/book_repository.dart';

class GetBooksUseCase {
  final BookRepository _repository;

  GetBooksUseCase(this._repository);

  Future<List<Book>> call() async {
    return await _repository.getBooks();
  }
}

class GetBookByIdUseCase {
  final BookRepository _repository;

  GetBookByIdUseCase(this._repository);

  Future<Book?> call(String id) async {
    return await _repository.getBookById(id);
  }
}

class AddBookUseCase {
  final BookRepository _repository;

  AddBookUseCase(this._repository);

  Future<void> call(Book book) async {
    await _repository.addBook(book);
  }
}

class UpdateBookUseCase {
  final BookRepository _repository;

  UpdateBookUseCase(this._repository);

  Future<void> call(Book book) async {
    await _repository.updateBook(book);
  }
}

class DeleteBookUseCase {
  final BookRepository _repository;

  DeleteBookUseCase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteBook(id);
  }
}

class SearchBooksUseCase {
  final BookRepository _repository;

  SearchBooksUseCase(this._repository);

  Future<List<Book>> call(String query) async {
    return await _repository.searchBooks(query);
  }
}

class GetBooksByCategoryUseCase {
  final BookRepository _repository;

  GetBooksByCategoryUseCase(this._repository);

  Future<List<Book>> call(String categoryId) async {
    return await _repository.getBooksByCategory(categoryId);
  }
}
