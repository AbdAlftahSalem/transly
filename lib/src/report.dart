/// Terminal and JSON output.
library;

import 'dart:convert';

import 'checker.dart';
import 'issue.dart';

/// ANSI styling that can be switched off.
class Ansi {
  /// Creates styling; [enabled] false returns text unchanged.
  const Ansi(this.enabled);

  /// Whether escape codes are written.
  final bool enabled;

  String _wrap(String code, String s) => enabled ? '\x1B[${code}m$s\x1B[0m' : s;

  /// Bold.
  String bold(String s) => _wrap('1', s);

  /// Dim.
  String dim(String s) => _wrap('2', s);

  /// Red.
  String red(String s) => _wrap('31', s);

  /// Green.
  String green(String s) => _wrap('32', s);

  /// Yellow.
  String yellow(String s) => _wrap('33', s);

  /// Blue.
  String blue(String s) => _wrap('34', s);

  /// Magenta.
  String magenta(String s) => _wrap('35', s);

  /// Cyan.
  String cyan(String s) => _wrap('36', s);

  /// Gray.
  String gray(String s) => _wrap('90', s);
}

final RegExp _ansiRe = RegExp('\x1B\\[[0-9;]*m');

/// The width of [s] on screen, ignoring ANSI codes.
int visibleWidth(String s) => s.replaceAll(_ansiRe, '').runes.length;

/// Pads [s] to [width] visible characters.
String pad(String s, int width, {bool right = false}) {
  final gap = width - visibleWidth(s);
  if (gap <= 0) return s;
  return right ? '${' ' * gap}$s' : '$s${' ' * gap}';
}

/// Renders rows as aligned columns. [right] lists right-aligned columns.
String table(List<List<String>> rows, {Set<int> right = const {}, String indent = '  ', String gap = '  '}) {
  if (rows.isEmpty) return '';
  final widths = List<int>.filled(rows.first.length, 0);
  for (final r in rows) {
    for (var i = 0; i < r.length; i++) {
      final w = visibleWidth(r[i]);
      if (w > widths[i]) widths[i] = w;
    }
  }
  return rows
      .map((r) =>
          indent +
          [for (var i = 0; i < r.length; i++) pad(r[i], widths[i], right: right.contains(i))].join(gap).trimRight())
      .join('\n');
}

/// The icon for a severity.
String severityIcon(Severity s, Ansi a) => switch (s) {
      Severity.error => a.red('✖'),
      Severity.warning => a.yellow('▲'),
      Severity.info => a.blue('●'),
    };

/// A 10-cell coverage bar.
String coverageBar(double coverage, Ansi a) {
  final filled = (coverage * 10).round().clamp(0, 10);
  final bar = '█' * filled;
  final rest = '░' * (10 - filled);
  final color = coverage >= 0.999 ? a.green : (coverage >= 0.8 ? a.yellow : a.red);
  return '${color(bar)}${a.gray(rest)}';
}

/// The per-locale summary table.
String localeTable(List<LocaleReport> reports, Ansi a) {
  String n(int v, String Function(String) color) => v == 0 ? a.gray('–') : color('$v');
  final rows = <List<String>>[
    ['Locale', 'File', 'Keys', 'Missing', 'Extra', 'Empty/TODO', 'Same as base', 'Placeholders', 'Coverage']
        .map(a.bold)
        .toList(),
  ];
  for (final r in reports) {
    final keys = r.file.entries.length;
    rows.add([
      r.isBase ? '${a.bold(r.locale)} ${a.cyan('★ base')}' : a.bold(r.locale),
      a.gray(r.file.fileName),
      '$keys',
      n(r.count(IssueKind.missingKey), a.red),
      n(r.count(IssueKind.extraKey), a.yellow),
      n(r.countAny(const [IssueKind.emptyValue, IssueKind.todoValue]), a.yellow),
      n(r.count(IssueKind.untranslated), a.yellow),
      n(r.countAny(const [IssueKind.placeholderMismatch, IssueKind.icuSyntax]), a.red),
      r.file.isValid
          ? '${coverageBar(r.coverage, a)} ${pad('${(r.coverage * 100).floor()}%', 4, right: true)}'
          : a.red('invalid JSON'),
    ]);
  }
  return table(rows, right: const {2, 3, 4, 5, 6, 7});
}

/// One issue as a line: icon, kind, where, message.
List<List<String>> issueRows(Iterable<Issue> issues, Ansi a, {bool showFile = false}) => [
      for (final i in issues)
        [
          severityIcon(i.severity, a),
          i.severity == Severity.error
              ? a.red(i.kind.id)
              : (i.severity == Severity.warning ? a.yellow(i.kind.id) : a.blue(i.kind.id)),
          showFile
              ? a.cyan(i.location ?? '')
              : (i.key == null
                  ? a.gray(i.line == null ? '' : 'line ${i.line}${i.column == null ? '' : ':${i.column}'}')
                  : '${a.bold(i.key!)}${i.line == null ? '' : a.gray(':${i.line}')}'),
          i.message,
        ],
    ];

/// Counts by severity.
({int errors, int warnings, int infos}) countSeverities(Iterable<Issue> issues) => (
      errors: issues.where((i) => i.severity == Severity.error).length,
      warnings: issues.where((i) => i.severity == Severity.warning).length,
      infos: issues.where((i) => i.severity == Severity.info).length,
    );

/// The closing line: `✖ 3 errors  ▲ 5 warnings`.
String summaryLine(Iterable<Issue> issues, Ansi a) {
  final c = countSeverities(issues);
  if (c.errors == 0 && c.warnings == 0) {
    return '${a.green('✔')} ${a.bold('All good.')}${c.infos == 0 ? '' : a.blue('  ● ${c.infos} to review')}';
  }
  String plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
  final parts = <String>[
    if (c.errors > 0) a.red('✖ ${plural(c.errors, 'error')}'),
    if (c.warnings > 0) a.yellow('▲ ${plural(c.warnings, 'warning')}'),
    if (c.infos > 0) a.blue('● ${c.infos} to review'),
  ];
  return a.bold(parts.join('  '));
}

/// Issues as GitHub Actions workflow commands (inline annotations).
List<String> githubAnnotations(Iterable<Issue> issues) {
  String esc(String s) => s.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');
  String prop(String s) => esc(s).replaceAll(':', '%3A').replaceAll(',', '%2C');
  return [
    for (final i in issues)
      if (i.severity != Severity.info)
        '::${i.severity == Severity.error ? 'error' : 'warning'}'
            '${i.file == null ? '' : ' file=${prop(i.file!)}${i.line == null ? '' : ',line=${i.line}'}${i.column == null ? '' : ',col=${i.column}'}'}'
            ',title=${prop('transly ${i.kind.id}')}'
            '::${esc('${i.locale == null ? '' : '[${i.locale}] '}${i.key == null ? '' : '${i.key}: '}${i.message}')}',
  ];
}

/// Pretty JSON.
String prettyJson(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
