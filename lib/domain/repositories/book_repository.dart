import 'package:myreader/domain/entities/book.dart';

abstract class BookRepository {
  Future<List<Book>> getBooks();
  Future<Book?> getBookById(String id);
  Future<void> addBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Future<List<Book>> searchBooks(String query);
  Future<List<Book>> getBooksByCategory(String categoryId);
}
