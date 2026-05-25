import 'dart:convert';
import 'dart:io';

import 'package:myreader/data/models/remote_catalog/catalog_book_model.dart';
import 'package:myreader/data/models/remote_catalog/catalog_chapter_model.dart';
import 'package:myreader/data/models/remote_catalog/catalog_manifest_model.dart';

typedef RemoteCatalogTransport =
    Future<RemoteCatalogResponse> Function(Uri uri);

class RemoteCatalogResponse {
  final int statusCode;
  final String body;

  const RemoteCatalogResponse({required this.statusCode, required this.body});
}

class RemoteCatalogApiException implements Exception {
  final Uri uri;
  final int statusCode;
  final String body;

  const RemoteCatalogApiException({
    required this.uri,
    required this.statusCode,
    required this.body,
  });

  @override
  String toString() {
    return 'RemoteCatalogApiException($statusCode, $uri)';
  }
}

class RemoteCatalogApiClient {
  final Uri baseUrl;
  final RemoteCatalogTransport _transport;

  RemoteCatalogApiClient({
    required this.baseUrl,
    RemoteCatalogTransport? transport,
    HttpClient? httpClient,
  }) : _transport = transport ?? _HttpClientTransport(httpClient).get;

  Future<List<CatalogBookSummaryModel>> fetchBooks({
    String? language,
    int? page,
    int? pageSize,
  }) async {
    final response = await _get(
      _buildUri(
        const ['books'],
        queryParameters: {
          if (language != null) 'language': language,
          if (page != null) 'page': page.toString(),
          if (pageSize != null) 'page_size': pageSize.toString(),
        },
      ),
    );
    final decoded = jsonDecode(response);
    final items = decoded is List<dynamic>
        ? decoded
        : _listPayload(decoded as Map<String, dynamic>);

    return items
        .cast<Map<String, dynamic>>()
        .map(CatalogBookSummaryModel.fromJson)
        .toList(growable: false);
  }

  Future<CatalogBookDetailModel> fetchBookDetail(String bookId) async {
    final response = await _get(_buildUri(['books', bookId]));
    return CatalogBookDetailModel.fromJson(
      _objectPayload(jsonDecode(response)),
    );
  }

  Future<CatalogManifestModel> fetchManifest(String bookId) async {
    final response = await _get(_buildUri(['books', bookId, 'manifest']));
    return CatalogManifestModel.fromJson(_objectPayload(jsonDecode(response)));
  }

  Future<CatalogChapterModel> fetchChapter(
    String bookId,
    String chapterId,
  ) async {
    final response = await _get(
      _buildUri(['books', bookId, 'chapters', chapterId]),
    );
    return CatalogChapterModel.fromJson(_objectPayload(jsonDecode(response)));
  }

  Uri _buildUri(
    List<String> pathSegments, {
    Map<String, String>? queryParameters,
  }) {
    final baseSegments = baseUrl.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    return baseUrl.replace(
      pathSegments: [...baseSegments, ...pathSegments],
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  Future<String> _get(Uri uri) async {
    final response = await _transport(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteCatalogApiException(
        uri: uri,
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return response.body;
  }

  List<dynamic> _listPayload(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is List<dynamic>) {
      return data;
    }
    final books = decoded['books'];
    if (books is List<dynamic>) {
      return books;
    }
    throw const FormatException('Expected catalog list payload.');
  }

  Map<String, dynamic> _objectPayload(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected catalog object payload.');
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return decoded;
  }
}

class _HttpClientTransport {
  final HttpClient _client;

  _HttpClientTransport(HttpClient? client) : _client = client ?? HttpClient();

  Future<RemoteCatalogResponse> get(Uri uri) async {
    final request = await _client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    return RemoteCatalogResponse(statusCode: response.statusCode, body: body);
  }
}
