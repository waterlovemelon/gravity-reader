import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${(seconds / 60).toInt()}分钟';
    return '${(seconds / 3600).toInt()}小时';
  }
}
