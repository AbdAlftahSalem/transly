/// Locale detection from translation file names.
library;

/// A locale found inside a file name.
class FileLocale {
  /// Creates a file locale.
  const FileLocale(this.locale, this.start);

  /// The locale exactly as written in the name (`en`, `en_US`, `pt-BR`).
  final String locale;

  /// Where the locale starts inside the name (without extension).
  final int start;
}

final RegExp _lang = RegExp(r'^[a-z]{2,3}$');
final RegExp _subtag = RegExp(r'^(?:[A-Za-z]{2}|[A-Z][a-z]{3}|[0-9]{3})$');

/// Finds the locale in a file name without its extension:
/// `app_en` → `en`, `intl_pt_BR` → `pt_BR`, `en-US` → `en-US`, `ar` → `ar`.
/// Returns null when the name has no locale.
FileLocale? localeFromFileName(String nameWithoutExtension) {
  final matches = RegExp(r'[^_\-.]+').allMatches(nameWithoutExtension).toList();
  for (var i = matches.length - 1; i >= 0; i--) {
    if (!_lang.hasMatch(matches[i][0]!)) continue;
    final rest = matches.skip(i + 1);
    if (rest.every((m) => _subtag.hasMatch(m[0]!))) {
      final start = matches[i].start;
      return FileLocale(nameWithoutExtension.substring(start), start);
    }
  }
  return null;
}

/// `en-US` and `en_us` both become `en_US`; `zh_hant_tw` becomes `zh_Hant_TW`.
String normalizeLocale(String locale) {
  final parts = locale.split(RegExp(r'[_\-]'));
  final out = <String>[parts.first.toLowerCase()];
  for (final p in parts.skip(1)) {
    if (p.length == 4) {
      out.add(p[0].toUpperCase() + p.substring(1).toLowerCase());
    } else {
      out.add(p.toUpperCase());
    }
  }
  return out.join('_');
}

/// The language part of a locale: `en_US` → `en`.
String languageOf(String locale) => locale.split(RegExp(r'[_\-]')).first.toLowerCase();
