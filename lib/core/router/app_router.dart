// App Router - Clean Architecture Presentation Layer
// Placeholder routing configuration - will be implemented with go_router in Wave 6

import 'package:flutter/material.dart';

class AppRouter {
  static const String home = '/';
  static const String bookshelf = '/bookshelf';
  static const String reader = '/reader';
  static const String readerSettings = '/reader/settings';
  static const String stats = '/stats';

  static Map<String, Widget Function(BuildContext)> routes = {};
}
