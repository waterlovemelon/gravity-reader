import 'package:myreader/domain/entities/bookmark.dart';
import 'package:myreader/domain/repositories/bookmark_repository.dart';

class GetBookmarksByBookIdUseCase {
  final BookmarkRepository _repository;

  GetBookmarksByBookIdUseCase(this._repository);

  Future<List<Bookmark>> call(String bookId) async {
    return await _repository.getBookmarksByBookId(bookId);
  }
}

class GetBookmarkByIdUseCase {
  final BookmarkRepository _repository;

  GetBookmarkByIdUseCase(this._repository);

  Future<Bookmark?> call(String id) async {
    return await _repository.getBookmarkById(id);
  }
}

class SaveBookmarkUseCase {
  final BookmarkRepository _repository;

  SaveBookmarkUseCase(this._repository);

  Future<void> call(Bookmark bookmark) async {
    await _repository.saveBookmark(bookmark);
  }
}

class DeleteBookmarkUseCase {
  final BookmarkRepository _repository;

  DeleteBookmarkUseCase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteBookmark(id);
  }
}
