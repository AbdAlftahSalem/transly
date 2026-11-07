/// Findings reported by the checks.
library;

/// How serious a finding is.
enum Severity {
  /// Breaks the build or the app (missing keys, broken placeholders).
  error,

  /// Probably wrong (untranslated text, unused keys, hardcoded strings).
  warning,

  /// Worth knowing (machine translations awaiting review).
  info;
}

/// The kind of a finding.
enum IssueKind {
  /// The file is not valid JSON.
  invalidJson('invalid-json', Severity.error),

  /// A key appears twice in the same object.
  duplicateKey('duplicate-key', Severity.error),

  /// A base key is missing in a locale.
  missingKey('missing', Severity.error),

  /// A key exists in a locale but not in the base.
  extraKey('extra', Severity.warning),

  /// The value is empty.
  emptyValue('empty', Severity.warning),

  /// The value starts with TODO / FIXME / TBD.
  todoValue('todo', Severity.warning),

  /// The value is the same as the base text.
  untranslated('untranslated', Severity.warning),

  /// Placeholders differ from the base.
  placeholderMismatch('placeholder', Severity.error),

  /// The ICU syntax is broken (braces, plural cases).
  icuSyntax('icu-syntax', Severity.error),

  /// `@@locale` does not match the file name.
  localeMismatch('locale-mismatch', Severity.warning),

  /// A base key that no Dart file references.
  unusedKey('unused', Severity.warning),

  /// Code references a key that does not exist in the base file.
  unknownKey('unknown-key', Severity.error),

  /// Code passes the wrong arguments for a key's placeholders.
  wrongArguments('wrong-args', Severity.error),

  /// A user-facing string literal in a widget that is not localized.
  hardcodedString('hardcoded', Severity.warning),

  /// A machine translation that nobody has reviewed yet.
  needsReview('needs-review', Severity.info);

  const IssueKind(this.id, this.severity);

  /// The short id used in reports and JSON output.
  final String id;

  /// The default severity.
  final Severity severity;
}

/// One finding.
class Issue {
  /// Creates a finding.
  const Issue(this.kind, this.message,
      {this.locale, this.key, this.file, this.line, this.column, this.severityOverride});

  /// The kind of finding.
  final IssueKind kind;

  /// A one-line explanation.
  final String message;

  /// The locale it concerns, if any.
  final String? locale;

  /// The translation key it concerns, if any.
  final String? key;

  /// The file it was found in (relative to the project root when possible).
  final String? file;

  /// The 1-based line, if known.
  final int? line;

  /// The 1-based column, if known.
  final int? column;

  /// Replaces the kind's default severity.
  final Severity? severityOverride;

  /// The effective severity.
  Severity get severity => severityOverride ?? kind.severity;

  /// `file:line` (or `file`) for display.
  String? get location => file == null ? null : (line == null ? file : '$file:$line');

  /// A JSON-friendly map.
  Map<String, Object?> toJson() => {
        'kind': kind.id,
        'severity': severity.name,
        if (locale != null) 'locale': locale,
        if (key != null) 'key': key,
        'message': message,
        if (file != null) 'file': file,
        if (line != null) 'line': line,
        if (column != null) 'column': column,
      };

  @override
  String toString() => '[${severity.name}] ${kind.id}${key == null ? '' : ' $key'}: $message';
}
