import 'package:myreader/data/datasources/local/book_local_data_source.dart';
import 'package:myreader/data/models/book_model.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/repositories/book_repository.dart';

class BookRepositoryImpl implements BookRepository {
  final BookLocalDataSource _localDataSource;

  BookRepositoryImpl(this._localDataSource);

  @override
  Future<List<Book>> getBooks() async {
    final models = await _localDataSource.getBooks();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Book?> getBookById(String id) async {
    final model = await _localDataSource.getBookById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addBook(Book book) async {
    final model = BookModel.fromEntity(book);
    await _localDataSource.insertBook(model);
  }

  @override
  Future<void> updateBook(Book book) async {
    final model = BookModel.fromEntity(book);
    await _localDataSource.updateBook(model);
  }

  @override
  Future<void> deleteBook(String id) async {
    await _localDataSource.deleteBook(id);
  }

  @override
  Future<List<Book>> searchBooks(String query) async {
    final models = await _localDataSource.searchBooks(query);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Book>> getBooksByCategory(String categoryId) async {
    final models = await _localDataSource.getBooksByCategory(categoryId);
    return models.map((model) => model.toEntity()).toList();
  }
}
