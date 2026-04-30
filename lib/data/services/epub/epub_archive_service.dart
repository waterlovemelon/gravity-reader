import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class EpubArchiveService {
  const EpubArchiveService();

  Future<Map<String, List<int>>> readEntries(String epubPath) async {
    final bytes = await File(epubPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return {
      for (final file in archive.files)
        if (file.isFile) file.name: List<int>.from(file.content as List<int>),
    };
  }

  String readUtf8(Map<String, List<int>> entries, String path) {
    final bytes = entries[path];
    if (bytes == null) {
      throw StateError('Missing archive entry: $path');
    }
    return utf8.decode(bytes);
  }

  List<int> readBytes(Map<String, List<int>> entries, String path) {
    final bytes = entries[path];
    if (bytes == null) {
      throw StateError('Missing archive entry: $path');
    }
    return bytes;
  }

  String readContainerPath(Map<String, List<int>> entries) {
    final document = XmlDocument.parse(
      readUtf8(entries, 'META-INF/container.xml'),
    );
    final rootfile = document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'rootfile',
    );
    final packagePath = rootfile.getAttribute('full-path');
    if (packagePath == null || packagePath.isEmpty) {
      throw StateError('Missing rootfile full-path in container.xml');
    }
    return packagePath;
  }

  String resolvePath({required String basePath, required String relativePath}) {
    final normalized = <String>[];
    final baseSegments = basePath.split('/');
    if (baseSegments.isNotEmpty) {
      baseSegments.removeLast();
      normalized.addAll(baseSegments.where((segment) => segment.isNotEmpty));
    }
    for (final segment in relativePath.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (normalized.isNotEmpty) {
          normalized.removeLast();
        }
        continue;
      }
      normalized.add(segment);
    }
    return normalized.join('/');
  }
}
