/// A small JSON reader that keeps key order, reports duplicate keys and
/// gives line and column numbers for syntax errors and keys.
library;

/// A key that appears more than once inside the same JSON object.
class DuplicateKey {
  /// Creates a duplicate-key record.
  const DuplicateKey(this.key, this.line, this.firstLine);

  /// The dotted path of the key (`home.title`).
  final String key;

  /// The line of the repeated occurrence (1-based).
  final int line;

  /// The line where the key first appeared (1-based).
  final int firstLine;
}

/// Thrown when a file is not valid JSON.
class JsonSyntaxError implements Exception {
  /// Creates a syntax error at [line]:[column] (both 1-based).
  JsonSyntaxError(this.message, this.line, this.column);

  /// What went wrong, in plain words.
  final String message;

  /// The 1-based line of the problem.
  final int line;

  /// The 1-based column of the problem.
  final int column;

  @override
  String toString() => '$message (line $line, column $column)';
}

/// The result of [readJson].
class JsonDocument {
  JsonDocument._(this.value, this.keyLines, this.duplicates);

  /// The decoded value. Objects are insertion-ordered maps.
  final Object? value;

  /// The 1-based line of every object key, by dotted path.
  final Map<String, int> keyLines;

  /// Keys repeated inside one object. The last value wins, like `jsonDecode`.
  final List<DuplicateKey> duplicates;
}

/// Parses [source] as JSON. Throws [JsonSyntaxError] with a line number when
/// the text is not valid JSON.
JsonDocument readJson(String source) => _Parser(source).parse();

class _Parser {
  _Parser(this.src) {
    _lineStarts.add(0);
    for (var i = 0; i < src.length; i++) {
      if (src.codeUnitAt(i) == 0x0A) _lineStarts.add(i + 1);
    }
  }

  final String src;
  final List<int> _lineStarts = [];
  final Map<String, int> _keyLines = {};
  final List<DuplicateKey> _dups = [];
  int pos = 0;

  JsonDocument parse() {
    if (src.startsWith('\uFEFF')) pos = 1;
    _ws();
    if (pos >= src.length) throw _err('the file is empty');
    final value = _value(const []);
    _ws();
    if (pos < src.length) {
      throw _err('unexpected text after the end of the JSON value');
    }
    return JsonDocument._(value, _keyLines, _dups);
  }

  int _peek() => pos < src.length ? src.codeUnitAt(pos) : -1;

  void _ws() {
    while (pos < src.length) {
      final c = src.codeUnitAt(pos);
      if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09) {
        pos++;
      } else {
        break;
      }
    }
  }

  int _line(int offset) {
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

  JsonSyntaxError _err(String message, [int? at]) {
    final offset = (at ?? pos).clamp(0, src.length);
    final line = _line(offset);
    return JsonSyntaxError(message, line, offset - _lineStarts[line - 1] + 1);
  }

  Object? _value(List<String> path) {
    _ws();
    final c = _peek();
    if (c == -1) throw _err('unexpected end of file');
    switch (c) {
      case 0x7B:
        return _object(path);
      case 0x5B:
        return _array(path);
      case 0x22:
        return _string();
      case 0x74:
        return _literal('true', true);
      case 0x66:
        return _literal('false', false);
      case 0x6E:
        return _literal('null', null);
    }
    if (c == 0x2D || (c >= 0x30 && c <= 0x39)) return _number();
    if (c == 0x27) throw _err("strings must use double quotes, not '");
    throw _err('unexpected character "${String.fromCharCode(c)}"');
  }

  Map<String, Object?> _object(List<String> path) {
    pos++;
    final map = <String, Object?>{};
    final seen = <String, int>{};
    _ws();
    if (_peek() == 0x7D) {
      pos++;
      return map;
    }
    while (true) {
      _ws();
      final c = _peek();
      if (c != 0x22) {
        if (c == 0x7D) throw _err('trailing comma before }');
        if (c == -1) throw _err('unexpected end of file, missing }');
        throw _err('expected a "quoted" key');
      }
      final keyLine = _line(pos);
      final key = _string();
      final full = [...path, key];
      final joined = full.join('.');
      final first = seen[key];
      if (first != null) {
        _dups.add(DuplicateKey(joined, keyLine, first));
      } else {
        seen[key] = keyLine;
        _keyLines[joined] = keyLine;
      }
      _ws();
      if (_peek() != 0x3A) throw _err('expected : after the key "$key"');
      pos++;
      map[key] = _value(full);
      final afterValue = pos;
      _ws();
      final n = _peek();
      if (n == 0x2C) {
        pos++;
        continue;
      }
      if (n == 0x7D) {
        pos++;
        return map;
      }
      if (n == 0x22) {
        throw _err('missing comma after the value of "$key"', afterValue);
      }
      if (n == -1) throw _err('unexpected end of file, missing }');
      throw _err('expected , or } after the value of "$key"');
    }
  }

  List<Object?> _array(List<String> path) {
    pos++;
    final list = <Object?>[];
    _ws();
    if (_peek() == 0x5D) {
      pos++;
      return list;
    }
    while (true) {
      list.add(_value([...path, '${list.length}']));
      _ws();
      final n = _peek();
      if (n == 0x2C) {
        pos++;
        _ws();
        if (_peek() == 0x5D) throw _err('trailing comma before ]');
        continue;
      }
      if (n == 0x5D) {
        pos++;
        return list;
      }
      if (n == -1) throw _err('unexpected end of file, missing ]');
      throw _err('expected , or ] in the list');
    }
  }

  String _string() {
    final start = pos;
    pos++;
    final buf = StringBuffer();
    while (true) {
      if (pos >= src.length) throw _err('unterminated string', start);
      final c = src.codeUnitAt(pos);
      if (c == 0x22) {
        pos++;
        return buf.toString();
      }
      if (c == 0x5C) {
        pos++;
        if (pos >= src.length) throw _err('unterminated string', start);
        final e = src.codeUnitAt(pos);
        switch (e) {
          case 0x22:
            buf.writeCharCode(0x22);
          case 0x5C:
            buf.writeCharCode(0x5C);
          case 0x2F:
            buf.writeCharCode(0x2F);
          case 0x62:
            buf.writeCharCode(0x08);
          case 0x66:
            buf.writeCharCode(0x0C);
          case 0x6E:
            buf.writeCharCode(0x0A);
          case 0x72:
            buf.writeCharCode(0x0D);
          case 0x74:
            buf.writeCharCode(0x09);
          case 0x75:
            if (pos + 4 >= src.length) throw _err('bad \\u escape');
            final hex = src.substring(pos + 1, pos + 5);
            final code = int.tryParse(hex, radix: 16);
            if (code == null) throw _err('bad \\u escape "\\u$hex"');
            buf.writeCharCode(code);
            pos += 4;
          default:
            throw _err('unknown escape "\\${String.fromCharCode(e)}"');
        }
        pos++;
        continue;
      }
      if (c < 0x20) {
        throw _err('line break or control character inside a string');
      }
      buf.writeCharCode(c);
      pos++;
    }
  }

  static final RegExp _numberRe = RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?');

  num _number() {
    final m = _numberRe.matchAsPrefix(src, pos);
    if (m == null) throw _err('invalid number');
    pos = m.end;
    return num.parse(m[0]!);
  }

  Object? _literal(String word, Object? value) {
    if (!src.startsWith(word, pos)) {
      throw _err('unexpected word, did you mean "$word"?');
    }
    pos += word.length;
    return value;
  }
}
