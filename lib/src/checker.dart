/// Compares every locale with the base locale.
library;

import 'config.dart';
import 'icu.dart';
import 'issue.dart';
import 'locale_name.dart';
import 'translation_file.dart';

/// Options for [checkFiles].
class CheckOptions {
  /// Creates options.
  const CheckOptions({
    this.checkIdentical = true,
    this.ignoreKeys = const [],
    this.ignoreUntranslated = const [],
    this.displayPath,
    this.machineTranslated = const {},
  });

  /// Report values that equal the base text.
  final bool checkIdentical;

  /// Keys skipped by every check (wildcards allowed).
  final List<String> ignoreKeys;

  /// Keys allowed to equal the base text (wildcards allowed).
  final List<String> ignoreUntranslated;

  /// Turns a file path into the path shown in reports.
  final String Function(String path)? displayPath;

  /// Machine translations awaiting review: locale → key → translated text.
  final Map<String, Map<String, String>> machineTranslated;
}

/// The result for one locale.
class LocaleReport {
  /// Creates an empty report for [file].
  LocaleReport(this.file, {required this.isBase});

  /// The file checked.
  final TranslationFile file;

  /// Whether this is the base locale.
  final bool isBase;

  /// The findings for this locale.
  final List<Issue> issues = [];

  /// How many keys the base has (after ignores).
  int baseKeys = 0;

  /// How many base keys have a real translation here.
  int translated = 0;

  /// The locale.
  String get locale => file.locale;

  /// Translated share, 0..1.
  double get coverage => baseKeys == 0 ? 1 : translated / baseKeys;

  /// How many findings of [kind].
  int count(IssueKind kind) => issues.where((i) => i.kind == kind).length;

  /// How many findings of any of [kinds].
  int countAny(Iterable<IssueKind> kinds) => issues.where((i) => kinds.contains(i.kind)).length;

  /// Number of errors.
  int get errors => issues.where((i) => i.severity == Severity.error).length;

  /// Number of warnings.
  int get warnings => issues.where((i) => i.severity == Severity.warning).length;
}

final RegExp _todo = RegExp(r'^\s*(TODO|FIXME|TBD)\b', caseSensitive: false);
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _acronym = RegExp(r'^[\p{Lu}0-9_\-\s.&/+]+$', unicode: true);
final RegExp _urlOrEmail = RegExp(r'^(https?://|www\.)\S+$|^\S+@\S+\.\S+$');

/// Whether [value] starts with TODO, FIXME or TBD.
bool isTodo(String value) => _todo.hasMatch(value);

/// Whether a base text is worth flagging when a locale repeats it unchanged.
/// Short words, numbers, acronyms, URLs and placeholder-only texts are not.
bool isWorthTranslating(String value) {
  final msg = parseIcu(value);
  final text = msg.nodes.whereType<IcuText>().map((n) => n.text).join().trim();
  if (msg.choices.isNotEmpty) return true;
  if (!_letter.hasMatch(text)) return false;
  if (text.runes.length < 4) return false;
  if (_acronym.hasMatch(text)) return false;
  if (_urlOrEmail.hasMatch(text)) return false;
  return true;
}

/// Checks [base] against each of [others] and returns one report per file,
/// base first.
List<LocaleReport> checkFiles(TranslationFile base, Iterable<TranslationFile> others,
    [CheckOptions options = const CheckOptions()]) {
  final ignore = KeyMatcher(options.ignoreKeys);
  final allowSame = KeyMatcher(options.ignoreUntranslated);
  String show(String path) => options.displayPath?.call(path) ?? path;

  final baseReport = LocaleReport(base, isBase: true);
  _fileIssues(base, baseReport, show);
  final reports = [baseReport];
  final baseKeys = base.entries.keys.where((k) => !ignore.matches(k)).toList();
  final baseMessages = <String, IcuMessage>{};
  baseReport.baseKeys = baseKeys.length;
  if (base.isValid) {
    for (final key in baseKeys) {
      final value = base.entries[key];
      if (value is! String) {
        baseReport.translated++;
        continue;
      }
      final msg = parseIcu(value);
      baseMessages[key] = msg;
      Issue at(IssueKind kind, String message) =>
          Issue(kind, message, locale: base.locale, key: key, file: show(base.path), line: base.lineOf(key));
      if (value.trim().isEmpty) {
        baseReport.issues.add(at(IssueKind.emptyValue, 'empty in the base locale'));
      } else if (isTodo(value)) {
        baseReport.issues.add(at(IssueKind.todoValue, 'TODO in the base locale: "${_short(value)}"'));
      } else {
        baseReport.translated++;
      }
      if (msg.error != null) baseReport.issues.add(at(IssueKind.icuSyntax, msg.error!));
      for (final c in msg.choices) {
        if (!c.hasOther) {
          baseReport.issues.add(at(IssueKind.icuSyntax, '{${c.name}, ${c.type}} has no "other" case'));
        }
      }
    }
  }

  for (final file in others) {
    final r = LocaleReport(file, isBase: false)..baseKeys = baseKeys.length;
    reports.add(r);
    _fileIssues(file, r, show);
    if (!file.isValid || !base.isValid) continue;
    Issue at(IssueKind kind, String key, String message) =>
        Issue(kind, message, locale: file.locale, key: key, file: show(file.path), line: file.lineOf(key));

    final declared = file.globals['@@locale'];
    if (declared is String &&
        file.fileLocale != null &&
        normalizeLocale(declared) != normalizeLocale(file.fileLocale!.locale)) {
      r.issues.add(Issue(
          IssueKind.localeMismatch, '@@locale is "$declared" but the file name says "${file.fileLocale!.locale}"',
          locale: file.locale, file: show(file.path), line: file.lines['@@locale']));
    }
    final sameLanguage = languageOf(file.locale) == languageOf(base.locale);
    final machine = options.machineTranslated[file.locale] ?? const {};

    for (final key in baseKeys) {
      final baseValue = base.entries[key];
      if (!file.entries.containsKey(key)) {
        r.issues.add(Issue(IssueKind.missingKey, 'missing (base: "${_short('$baseValue')}")',
            locale: file.locale, key: key, file: show(file.path)));
        continue;
      }
      final value = file.entries[key];
      if (value is! String || baseValue is! String) {
        r.translated++;
        continue;
      }
      if (value.trim().isEmpty) {
        r.issues.add(at(IssueKind.emptyValue, key, 'empty (base: "${_short(baseValue)}")'));
        continue;
      }
      if (isTodo(value)) {
        r.issues.add(at(IssueKind.todoValue, key, 'not translated yet: "${_short(value)}"'));
        continue;
      }
      r.translated++;
      final msg = parseIcu(value);
      final baseMsg = baseMessages[key]!;
      if (msg.error != null) {
        r.issues.add(at(IssueKind.icuSyntax, key, msg.error!));
      } else if (baseMsg.error == null) {
        for (final problem in comparePlaceholders(baseMsg, msg)) {
          r.issues.add(at(IssueKind.placeholderMismatch, key, problem));
        }
      }
      if (options.checkIdentical &&
          !sameLanguage &&
          value == baseValue &&
          !allowSame.matches(key) &&
          isWorthTranslating(baseValue)) {
        r.translated--;
        r.issues.add(at(IssueKind.untranslated, key, 'same as base: "${_short(value)}"'));
      }
      final mt = machine[key];
      final meta = file.metadata[key];
      final flagged = meta is Map && meta['x-translated'] == 'auto';
      if ((mt != null && mt == value) || (flagged && (mt == null || mt == value))) {
        r.issues.add(at(IssueKind.needsReview, key, 'machine translation, not reviewed yet: "${_short(value)}"'));
      }
    }
    for (final key in file.entries.keys) {
      if (base.entries.containsKey(key) || ignore.matches(key)) continue;
      r.issues.add(at(IssueKind.extraKey, key, 'not in the base locale ${base.locale}'));
    }
  }
  return reports;
}

/// Lists the placeholder differences between a base message and a translation.
List<String> comparePlaceholders(IcuMessage base, IcuMessage translation) {
  final out = <String>[];
  final a = base.arguments;
  final b = translation.arguments;
  for (final name in a.keys) {
    if (!b.containsKey(name)) {
      out.add('{$name} is missing');
    } else if (_isChoice(a[name]!) != _isChoice(b[name]!) || (_isChoice(a[name]!) && a[name] != b[name])) {
      out.add('{$name} is ${_kind(a[name]!)} in the base but ${_kind(b[name]!)} here');
    }
  }
  for (final name in b.keys) {
    if (!a.containsKey(name)) out.add('{$name} is not in the base text');
  }
  if (base.positionalCount != translation.positionalCount) {
    out.add('${translation.positionalCount} positional {} here, ${base.positionalCount} in the base');
  }
  for (final c in translation.choices) {
    if (!c.hasOther) out.add('{${c.name}, ${c.type}} has no "other" case');
  }
  return out;
}

bool _isChoice(String type) => type == 'plural' || type == 'select' || type == 'selectordinal';
String _kind(String type) => _isChoice(type) ? 'a $type' : 'plain';

void _fileIssues(TranslationFile f, LocaleReport r, String Function(String) show) {
  final err = f.error;
  if (err != null) {
    r.issues.add(Issue(IssueKind.invalidJson, err.message,
        locale: f.locale, file: show(f.path), line: err.line, column: err.column));
  }
  for (final d in f.duplicates) {
    r.issues.add(Issue(IssueKind.duplicateKey, 'defined twice (first on line ${d.firstLine}); the last one wins',
        locale: f.locale, key: d.key, file: show(f.path), line: d.line));
  }
}

String _short(String s, [int max = 48]) {
  final one = s.replaceAll('\n', r'\n');
  final runes = one.runes.toList();
  return runes.length <= max ? one : '${String.fromCharCodes(runes.take(max - 1))}…';
}
