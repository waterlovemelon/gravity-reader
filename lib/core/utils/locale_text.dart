import 'package:flutter/widgets.dart';

class LocaleText {
  const LocaleText._();

  static bool isChinese(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode.toLowerCase().startsWith('zh');
  }

  static String of(
    BuildContext context, {
    required String zh,
    required String en,
  }) {
    return isChinese(context) ? zh : en;
  }
}
