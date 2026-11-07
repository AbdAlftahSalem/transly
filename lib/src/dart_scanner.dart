/// A light Dart lexer: finds string literals and comments, and gives a
/// "masked" copy of the code where both are blanked out, so regexes can
/// look at code without tripping over text.
library;

/// A string literal found in Dart code.
class DartString {
  /// Creates a literal record.
  const DartString({
    required this.value,
    required this.start,
    required this.end,
    required this.line,
    required this.column,
    required this.interpolated,
    required this.staticPrefix,
  });

  /// The text with escapes decoded; interpolations appear as `{expr}`.
  final String value;

  /// Offset of the first character (the `r` prefix or the quote).
  final int start;

  /// Offset just after the closing quote.
  final int end;

  /// 1-based line of [start].
  final int line;

  /// 1-based column of [start].
  final int column;

  /// Whether the string contains `$x` or `${...}`.
  final bool interpolated;

  /// The text before the first interpolation (all of it when none).
  final String staticPrefix;
}

/// A comment found in Dart code.
class DartComment {
  /// Creates a comment record.
  const DartComment(this.text, this.line, this.endLine, {required this.ownLine});

  /// The comment text, markers included.
  final String text;

  /// 1-based first line.
  final int line;

  /// 1-based last line.
  final int endLine;

  /// Whether nothing but whitespace precedes it on its line.
  final bool ownLine;
}

/// The result of [scanDart].
class DartScan {
  DartScan._(this.source, this.masked, this.strings, this.comments, this._lineStarts);

  /// The original code.
  final String source;

  /// The code with comments replaced by spaces and every string literal
  /// replaced by `"` + spaces + `"` of the same length (line breaks kept).
  final String masked;

  /// String literals, in order. Strings inside interpolations are included.
  final List<DartString> strings;

  /// Comments, in order.
  final List<DartComment> comments;

  final List<int> _lineStarts;

  /// 1-based line of [offset].
  int lineOf(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  /// 1-based column of [offset].
  int columnOf(int offset) => offset - _lineStarts[lineOf(offset) - 1] + 1;

  /// Whether [line] is silenced by an ignore [marker] comment on the same
  /// line or on its own line directly above.
  bool isIgnored(int line, String marker) {
    for (final c in comments) {
      if (!c.text.contains(marker)) continue;
      if (c.line <= line && c.endLine >= line) return true;
      if (c.ownLine && c.endLine == line - 1) return true;
    }
    return false;
  }

  /// Whether a comment anywhere contains [marker].
  bool hasComment(String marker) => comments.any((c) => c.text.contains(marker));
}

bool _isIdent(int c) =>
    (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F || c == 0x24;

/// Scans [source].
DartScan scanDart(String source) {
  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) lineStarts.add(i + 1);
  }
  final masked = source.codeUnits.toList();
  final strings = <DartString>[];
  final comments = <DartComment>[];
  int lineOf(int offset) {
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  void blank(int from, int to, {bool keepQuotes = false}) {
    for (var k = from; k < to && k < masked.length; k++) {
      if (masked[k] != 0x0A) masked[k] = 0x20;
    }
    if (keepQuotes && to - from >= 2) {
      masked[from] = 0x22;
      masked[to - 1] = 0x22;
    }
  }

  final s = source;
  final n = s.length;

  // Reads a string starting at [i] (at the r prefix or the quote).
  // Returns the offset after it. Nested strings in interpolations are recorded too.
  late int Function(int i) readString;

  int skipInterpolation(int i) {
    // i is just after "${". Returns the offset after the matching "}".
    var depth = 1;
    while (i < n) {
      final c = s.codeUnitAt(i);
      if (c == 0x27 ||
          c == 0x22 ||
          (c == 0x72 && i + 1 < n && (s.codeUnitAt(i + 1) == 0x27 || s.codeUnitAt(i + 1) == 0x22))) {
        i = readString(i);
        continue;
      }
      if (c == 0x7B) depth++;
      if (c == 0x7D) {
        depth--;
        if (depth == 0) return i + 1;
      }
      i++;
    }
    return n;
  }

  readString = (int start) {
    var i = start;
    var raw = false;
    if (s.codeUnitAt(i) == 0x72) {
      raw = true;
      i++;
    }
    final q = s.codeUnitAt(i);
    final triple = i + 2 < n && s.codeUnitAt(i + 1) == q && s.codeUnitAt(i + 2) == q;
    i += triple ? 3 : 1;
    final value = StringBuffer();
    String? prefix;
    var interpolated = false;
    final nested = <DartString>[];
    final before = strings.length;
    while (i < n) {
      final c = s.codeUnitAt(i);
      if (c == q) {
        if (!triple) {
          i++;
          break;
        }
        if (i + 2 < n && s.codeUnitAt(i + 1) == q && s.codeUnitAt(i + 2) == q) {
          i += 3;
          break;
        }
      }
      if (!triple && c == 0x0A) break; // unterminated: stop at the line end
      if (!raw && c == 0x5C && i + 1 < n) {
        final e = s[i + 1];
        value.write(switch (e) { 'n' => '\n', 't' => '\t', 'r' => '\r', _ => e });
        i += 2;
        continue;
      }
      if (!raw && c == 0x24 && i + 1 < n) {
        final next = s.codeUnitAt(i + 1);
        if (next == 0x7B) {
          prefix ??= value.toString();
          interpolated = true;
          final end = skipInterpolation(i + 2);
          value.write('{${s.substring(i + 2, (end - 1).clamp(i + 2, n))}}');
          i = end;
          continue;
        }
        if (_isIdent(next) && next != 0x24 && !(next >= 0x30 && next <= 0x39)) {
          prefix ??= value.toString();
          interpolated = true;
          var j = i + 1;
          while (j < n && _isIdent(s.codeUnitAt(j)) && s.codeUnitAt(j) != 0x24) {
            j++;
          }
          value.write('{${s.substring(i + 1, j)}}');
          i = j;
          continue;
        }
      }
      value.writeCharCode(c);
      i++;
    }
    // Strings recorded while skipping interpolations are kept, after this one.
    nested.addAll(strings.sublist(before));
    strings.removeRange(before, strings.length);
    final text = value.toString();
    strings.add(DartString(
      value: text,
      start: start,
      end: i,
      line: lineOf(start),
      column: start - lineStarts[lineOf(start) - 1] + 1,
      interpolated: interpolated,
      staticPrefix: prefix ?? text,
    ));
    strings.addAll(nested);
    return i;
  };

  var i = 0;
  while (i < n) {
    final c = s.codeUnitAt(i);
    if (c == 0x2F && i + 1 < n) {
      final d = s.codeUnitAt(i + 1);
      if (d == 0x2F) {
        var j = s.indexOf('\n', i);
        if (j == -1) j = n;
        final line = lineOf(i);
        final ownLine = s.substring(lineStarts[line - 1], i).trim().isEmpty;
        comments.add(DartComment(s.substring(i, j), line, line, ownLine: ownLine));
        blank(i, j);
        i = j;
        continue;
      }
      if (d == 0x2A) {
        var depth = 1;
        var j = i + 2;
        while (j < n && depth > 0) {
          if (s.startsWith('/*', j)) {
            depth++;
            j += 2;
          } else if (s.startsWith('*/', j)) {
            depth--;
            j += 2;
          } else {
            j++;
          }
        }
        final line = lineOf(i);
        final ownLine = s.substring(lineStarts[line - 1], i).trim().isEmpty;
        comments.add(DartComment(s.substring(i, j), line, lineOf(j - 1), ownLine: ownLine));
        blank(i, j);
        i = j;
        continue;
      }
    }
    final prevIsIdent = i > 0 && _isIdent(s.codeUnitAt(i - 1));
    if (c == 0x27 ||
        c == 0x22 ||
        (c == 0x72 && !prevIsIdent && i + 1 < n && (s.codeUnitAt(i + 1) == 0x27 || s.codeUnitAt(i + 1) == 0x22))) {
      final end = readString(i);
      blank(i, end, keepQuotes: true);
      i = end;
      continue;
    }
    i++;
  }
  strings.sort((a, b) => a.start.compareTo(b.start));
  return DartScan._(source, String.fromCharCodes(masked), strings, comments, lineStarts);
}

/// Finds the offset of the bracket that closes the one at [open] in masked
/// code (`(`→`)`, `[`→`]`, `{`→`}`). Returns -1 when unbalanced.
int matchingBracket(String masked, int open) {
  const pairs = {0x28: 0x29, 0x5B: 0x5D, 0x7B: 0x7D};
  final stack = <int>[];
  for (var i = open; i < masked.length; i++) {
    final c = masked.codeUnitAt(i);
    if (pairs.containsKey(c)) {
      stack.add(pairs[c]!);
    } else if (stack.isNotEmpty && c == stack.last) {
      stack.removeLast();
      if (stack.isEmpty) return i;
    }
  }
  return -1;
}

/// Splits the masked text between brackets at top-level commas and returns
/// the non-empty parts.
List<String> splitTopLevel(String inner) {
  final parts = <String>[];
  var depth = 0;
  var last = 0;
  for (var i = 0; i < inner.length; i++) {
    final c = inner[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      parts.add(inner.substring(last, i));
      last = i + 1;
    }
  }
  parts.add(inner.substring(last));
  return parts.where((x) => x.trim().isNotEmpty).toList();
}
