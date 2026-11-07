/// The sidecar list of machine translations awaiting human review.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'version.dart';

/// Machine translations awaiting review, stored in [reviewFileName] at the
/// project root. An entry counts as reviewed as soon as the value in the
/// translation file is edited (it no longer equals the machine text) or the
/// entry is removed from this file.
class ReviewLog {
  ReviewLog._(this.path, this.locales);

  /// Reads the log in [root] (empty when the file does not exist).
  factory ReviewLog.read(String root) {
    final path = p.join(root, reviewFileName);
    final file = File(path);
    final locales = <String, Map<String, ReviewEntry>>{};
    if (file.existsSync()) {
      try {
        final data = jsonDecode(file.readAsStringSync());
        final map = data is Map ? data['locales'] : null;
        if (map is Map) {
          map.forEach((locale, keys) {
            if (keys is! Map) return;
            locales['$locale'] = {
              for (final e in keys.entries)
                if (e.value is Map)
                  '${e.key}': ReviewEntry('${(e.value as Map)['source']}', '${(e.value as Map)['translation']}',
                      '${(e.value as Map)['engine'] ?? ''}'),
            };
          });
        }
      } on FormatException {
        // A broken log is treated as empty and rewritten on the next translate.
      }
    }
    return ReviewLog._(path, locales);
  }

  /// The file path.
  final String path;

  /// Locale → key → entry.
  final Map<String, Map<String, ReviewEntry>> locales;

  /// Locale → key → machine text, for the checker.
  Map<String, Map<String, String>> get machineText => {
        for (final l in locales.entries) l.key: {for (final e in l.value.entries) e.key: e.value.translation},
      };

  /// Records a machine translation.
  void add(String locale, String key, ReviewEntry entry) => (locales[locale] ??= {})[key] = entry;

  /// Writes the log.
  void write() {
    final data = {
      'about': 'Machine translations made by $toolName that a person has not reviewed yet. '
          'Edit the value in the translation file (or delete the entry here) once checked.',
      'locales': {
        for (final l in locales.entries)
          if (l.value.isNotEmpty) l.key: {for (final e in l.value.entries) e.key: e.value.toJson()},
      },
    };
    File(path).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  }
}

/// One machine translation.
class ReviewEntry {
  /// Creates an entry.
  const ReviewEntry(this.source, this.translation, this.engine);

  /// The base text.
  final String source;

  /// The machine translation written to the file.
  final String translation;

  /// The engine that made it.
  final String engine;

  /// JSON form.
  Map<String, String> toJson() => {'source': source, 'translation': translation, 'engine': engine};
}
