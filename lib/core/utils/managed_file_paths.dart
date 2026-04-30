import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef AppDirectoryProvider = Future<Directory> Function();

Future<File> resolveManagedFile(
  String? rawPath, {
  required String managedFolderName,
  AppDirectoryProvider appDirProvider = getApplicationDocumentsDirectory,
}) async {
  final normalizedPath = _normalizeFilePath(rawPath);
  if (normalizedPath.isEmpty) {
    return File('');
  }

  final directCandidates = <String>{
    normalizedPath,
    _safeDecode(normalizedPath),
  };
  for (final candidate in directCandidates) {
    if (candidate.isNotEmpty && await File(candidate).exists()) {
      return File(candidate);
    }
  }

  final appDir = await appDirProvider();
  final appDirPath = appDir.path;
  if (_isRelativeManagedPath(normalizedPath, managedFolderName)) {
    return File('$appDirPath/$normalizedPath');
  }

  if (_looksLikeManagedPath(normalizedPath, managedFolderName)) {
    final fileName = _lastPathSegment(normalizedPath);
    if (fileName.isNotEmpty) {
      return File('$appDirPath/$managedFolderName/$fileName');
    }
  }

  return File(normalizedPath);
}

bool looksLikeManagedFilePath(String? rawPath, String managedFolderName) {
  final normalizedPath = _normalizeFilePath(rawPath);
  return _isRelativeManagedPath(normalizedPath, managedFolderName) ||
      _looksLikeManagedPath(normalizedPath, managedFolderName);
}

String _normalizeFilePath(String? rawPath) {
  final trimmed = rawPath?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }

  if (trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      return uri.toFilePath();
    }
  }

  return trimmed;
}

bool _isRelativeManagedPath(String path, String managedFolderName) {
  final prefix = '$managedFolderName/';
  return path == managedFolderName || path.startsWith(prefix);
}

bool _looksLikeManagedPath(String path, String managedFolderName) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/$managedFolderName/');
}

String _lastPathSegment(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/').where((part) => part.isNotEmpty);
  return segments.isEmpty ? '' : segments.last;
}

String _safeDecode(String value) {
  try {
    return Uri.decodeFull(value);
  } catch (_) {
    return value;
  }
}
