/// Loading `.arb` and `.json` translation files.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'json_reader.dart';
import 'locale_name.dart';

/// The two supported file formats.
enum TranslationFormat {
  /// Flutter gen-l10n Application Resource Bundle files (`app_en.arb`).
  arb,

  /// Flat or nested JSON files (`en.json`), as used by easy_localization.
  json;

  /// The file extension, with the dot.
  String get extension => this == arb ? '.arb' : '.json';

  /// Parses `arb` / `json`; returns null for anything else.
  static TranslationFormat? tryParse(String? value) => switch (value?.toLowerCase()) {
        'arb' => TranslationFormat.arb,
        'json' => TranslationFormat.json,
        _ => null,
      };
}

/// One translation file, parsed.
///
/// Message keys are flattened: nested JSON `{"home": {"title": "Hi"}}`
/// becomes the key `home.title`. ARB `@key` metadata and `@@locale` style
/// global attributes are kept apart from the messages.
class TranslationFile {
  TranslationFile._({
    required this.path,
    required this.source,
    required this.format,
    required this.locale,
    required this.fileLocale,
    required this.entries,
    required this.keyPaths,
    required this.metadata,
    required this.globals,
    required this.lines,
    required this.duplicates,
    required this.error,
    required this.nested,
    required this.indent,
    required this.endsWithNewline,
  });

  /// Reads and parses the file at [path].
  factory TranslationFile.load(String path, {TranslationFormat? format}) =>
      TranslationFile.parse(path, File(path).readAsStringSync(), format: format);

  /// Parses [source] as the content of the file at [path].
  factory TranslationFile.parse(String path, String source, {TranslationFormat? format}) {
    final fmt = format ?? (p.extension(path).toLowerCase() == '.arb' ? TranslationFormat.arb : TranslationFormat.json);
    final name = p.basenameWithoutExtension(path);
    final fileLocale = localeFromFileName(name);
    final entries = <String, Object?>{};
    final keyPaths = <String, List<String>>{};
    final metadata = <String, Object?>{};
    final globals = <String, Object?>{};
    var lines = <String, int>{};
    var duplicates = <DuplicateKey>[];
    JsonSyntaxError? error;
    var nested = false;
    try {
      final doc = readJson(source);
      lines = doc.keyLines;
      duplicates = doc.duplicates;
      final value = doc.value;
      if (value is! Map<String, Object?>) {
        throw JsonSyntaxError('the top level must be a JSON object { ... }', 1, 1);
      }
      if (fmt == TranslationFormat.arb) {
        value.forEach((key, v) {
          if (key.startsWith('@@')) {
            globals[key] = v;
          } else if (key.startsWith('@')) {
            metadata[key.substring(1)] = v;
          } else {
            entries[key] = v;
            keyPaths[key] = [key];
          }
        });
      } else {
        nested = value.values.any((v) => v is Map);
        void walk(Map<String, Object?> map, List<String> path) {
          map.forEach((key, v) {
            final full = [...path, key];
            if (v is Map<String, Object?> && v.isNotEmpty) {
              walk(v, full);
            } else {
              final joined = full.join('.');
              entries[joined] = v;
              keyPaths[joined] = full;
            }
          });
        }

        walk(value, const []);
      }
    } on JsonSyntaxError catch (e) {
      error = e;
    }
    final declared = globals['@@locale'];
    final locale = declared is String && declared.isNotEmpty ? declared : (fileLocale?.locale ?? name);
    final indentMatch = RegExp(r'\n([ \t]+)\S').firstMatch(source);
    return TranslationFile._(
      path: path,
      source: source,
      format: fmt,
      locale: locale,
      fileLocale: fileLocale,
      entries: entries,
      keyPaths: keyPaths,
      metadata: metadata,
      globals: globals,
      lines: lines,
      duplicates: duplicates,
      error: error,
      nested: nested,
      indent: indentMatch?.group(1) ?? '  ',
      endsWithNewline: source.isEmpty || source.endsWith('\n'),
    );
  }

  /// The file path.
  final String path;

  /// The raw file content.
  final String source;

  /// The file format.
  final TranslationFormat format;

  /// The locale: `@@locale` for ARB files, else the one in the file name.
  final String locale;

  /// The locale found in the file name, if any.
  final FileLocale? fileLocale;

  /// Message keys (flattened) and values, in file order.
  final Map<String, Object?> entries;

  /// The original JSON path of every key, for writing nested files back.
  final Map<String, List<String>> keyPaths;

  /// ARB `@key` metadata, by message key (without the `@`).
  final Map<String, Object?> metadata;

  /// ARB `@@` attributes such as `@@locale`, in file order.
  final Map<String, Object?> globals;

  /// The 1-based line of every key, by dotted path.
  final Map<String, int> lines;

  /// Keys repeated inside one object.
  final List<DuplicateKey> duplicates;

  /// The syntax error, when the file is not valid JSON.
  final JsonSyntaxError? error;

  /// Whether a JSON file uses nested objects.
  final bool nested;

  /// The indentation unit used in the file (defaults to two spaces).
  final String indent;

  /// Whether the file ends with a line break.
  final bool endsWithNewline;

  /// Whether the file parsed as a JSON object.
  bool get isValid => error == null;

  /// The file name.
  String get fileName => p.basename(path);

  /// The value of [key] when it is a string.
  String? stringValue(String key) {
    final v = entries[key];
    return v is String ? v : null;
  }

  /// The line of [key], or null.
  int? lineOf(String key) => lines[format == TranslationFormat.arb ? key : (keyPaths[key]?.join('.') ?? key)];
}
