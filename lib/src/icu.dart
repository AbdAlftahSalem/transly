/// A tolerant parser for ICU MessageFormat strings as used by Flutter's
/// gen-l10n (`{name}`, `{count, plural, one{...} other{...}}`,
/// `{gender, select, male{...} other{...}}`) and by easy_localization
/// (`{}` positional and `{name}` named arguments).
library;

/// A piece of a parsed message.
sealed class IcuNode {
  const IcuNode();

  /// Writes the node back as message text.
  String render();
}

/// Literal text.
class IcuText extends IcuNode {
  /// Creates literal text.
  const IcuText(this.text);

  /// The text, exactly as written.
  final String text;

  @override
  String render() => text;
}

/// A simple argument: `{name}`, `{}`, or a typed one like `{price, number}`.
class IcuArgument extends IcuNode {
  /// Creates a simple argument.
  const IcuArgument(this.name, this.raw, {this.type});

  /// The argument name. Empty for the positional `{}`.
  final String name;

  /// An optional type such as `number`, `date` or `time`.
  final String? type;

  /// The source text, braces included.
  final String raw;

  /// Whether this is easy_localization's positional `{}`.
  bool get isPositional => name.isEmpty;

  @override
  String render() => raw;
}

/// One branch of a plural or select argument: `one{1 item}`.
class IcuBranch {
  /// Creates a branch.
  const IcuBranch(this.selector, this.message);

  /// The selector: `=0`, `one`, `other`, `male`, ...
  final String selector;

  /// The branch's own message.
  final List<IcuNode> message;
}

/// A `plural`, `select` or `selectordinal` argument.
class IcuChoice extends IcuNode {
  /// Creates a choice argument.
  const IcuChoice(this.name, this.type, this.branches);

  /// The argument name (`count`).
  final String name;

  /// `plural`, `select` or `selectordinal`.
  final String type;

  /// The branches, in source order.
  final List<IcuBranch> branches;

  /// Whether the mandatory `other` branch is present.
  bool get hasOther => branches.any((b) => b.selector == 'other');

  @override
  String render() {
    final b = StringBuffer('{$name, $type,');
    for (final branch in branches) {
      b.write(' ${branch.selector}{${renderMessage(branch.message)}}');
    }
    b.write('}');
    return b.toString();
  }
}

/// A parsed message.
class IcuMessage {
  /// Creates a parsed message.
  const IcuMessage(this.nodes, {this.error});

  /// The top-level nodes.
  final List<IcuNode> nodes;

  /// A syntax problem, or null when the message parsed cleanly.
  final String? error;

  /// Every named argument used anywhere in the message, with its kind
  /// (`plural`, `select`, `selectordinal`, a simple type like `number`,
  /// or `''` for a plain `{name}`).
  Map<String, String> get arguments {
    final out = <String, String>{};
    void walk(List<IcuNode> nodes) {
      for (final n in nodes) {
        if (n is IcuArgument && !n.isPositional) {
          out.putIfAbsent(n.name, () => n.type ?? '');
        } else if (n is IcuChoice) {
          out[n.name] = n.type;
          for (final b in n.branches) {
            walk(b.message);
          }
        }
      }
    }

    walk(nodes);
    return out;
  }

  /// How many positional `{}` arguments the message has (easy_localization).
  int get positionalCount {
    var count = 0;
    void walk(List<IcuNode> nodes) {
      for (final n in nodes) {
        if (n is IcuArgument && n.isPositional) count++;
        if (n is IcuChoice) {
          for (final b in n.branches) {
            walk(b.message);
          }
        }
      }
    }

    walk(nodes);
    return count;
  }

  /// Every plural/select argument, anywhere in the message.
  List<IcuChoice> get choices {
    final out = <IcuChoice>[];
    void walk(List<IcuNode> nodes) {
      for (final n in nodes) {
        if (n is IcuChoice) {
          out.add(n);
          for (final b in n.branches) {
            walk(b.message);
          }
        }
      }
    }

    walk(nodes);
    return out;
  }
}

/// Renders [nodes] back to message text.
String renderMessage(List<IcuNode> nodes) => nodes.map((n) => n.render()).join();

final RegExp _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
final RegExp _selector = RegExp(r'=?[A-Za-z0-9_+\-]+');
const Set<String> _choiceTypes = {'plural', 'select', 'selectordinal'};

/// Parses an ICU message. Never throws: problems are reported in
/// [IcuMessage.error] and the text is kept as literal text.
IcuMessage parseIcu(String text) {
  final p = _IcuParser(text);
  try {
    final nodes = p.message(topLevel: true);
    return IcuMessage(nodes);
  } on FormatException catch (e) {
    return IcuMessage([IcuText(text)], error: e.message);
  }
}

class _IcuParser {
  _IcuParser(this.s);

  final String s;
  int i = 0;

  void ws() {
    while (i < s.length && ' \t\n\r'.contains(s[i])) {
      i++;
    }
  }

  List<IcuNode> message({required bool topLevel}) {
    final nodes = <IcuNode>[];
    final text = StringBuffer();
    void flush() {
      if (text.isNotEmpty) {
        nodes.add(IcuText(text.toString()));
        text.clear();
      }
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '}') {
        if (topLevel) {
          throw const FormatException('unbalanced braces: a "}" has no "{"');
        }
        break;
      }
      if (c == '{') {
        flush();
        nodes.add(argument());
        continue;
      }
      text.write(c);
      i++;
    }
    flush();
    return nodes;
  }

  IcuNode argument() {
    final start = i;
    i++; // {
    ws();
    if (i < s.length && s[i] == '}') {
      i++;
      return IcuArgument('', s.substring(start, i));
    }
    final name = _identifier.matchAsPrefix(s, i);
    if (name == null) return literalBlock(start);
    i = name.end;
    ws();
    if (i >= s.length) {
      throw FormatException('unbalanced braces: "{${name[0]}" is never closed');
    }
    if (s[i] == '}') {
      i++;
      return IcuArgument(name[0]!, s.substring(start, i));
    }
    if (s[i] != ',') return literalBlock(start);
    i++;
    ws();
    final type = _identifier.matchAsPrefix(s, i);
    if (type == null) {
      throw FormatException('missing argument type after "{${name[0]},"');
    }
    i = type.end;
    ws();
    if (!_choiceTypes.contains(type[0])) {
      // {price, number} or {when, date, yMd}: skip to the matching brace.
      var depth = 1;
      while (i < s.length && depth > 0) {
        if (s[i] == '{') depth++;
        if (s[i] == '}') depth--;
        i++;
      }
      if (depth != 0) {
        throw FormatException('unbalanced braces in "{${name[0]}, ${type[0]}"');
      }
      return IcuArgument(name[0]!, s.substring(start, i), type: type[0]);
    }
    if (i >= s.length || s[i] != ',') {
      throw FormatException('expected "," after "{${name[0]}, ${type[0]}"');
    }
    i++;
    final branches = <IcuBranch>[];
    while (true) {
      ws();
      if (i >= s.length) {
        throw FormatException('"{${name[0]}, ${type[0]}" is never closed');
      }
      if (s[i] == '}') {
        i++;
        break;
      }
      final sel = _selector.matchAsPrefix(s, i);
      if (sel == null) {
        throw FormatException('bad ${type[0]} selector near "${s.substring(i, (i + 10).clamp(0, s.length))}"');
      }
      i = sel.end;
      ws();
      if (i >= s.length || s[i] != '{') {
        throw FormatException('expected "{" after the ${type[0]} case "${sel[0]}"');
      }
      i++;
      final body = message(topLevel: false);
      if (i >= s.length || s[i] != '}') {
        throw FormatException('the ${type[0]} case "${sel[0]}" is never closed');
      }
      i++;
      branches.add(IcuBranch(sel[0]!, body));
    }
    if (branches.isEmpty) {
      throw FormatException('"{${name[0]}, ${type[0]}" has no cases');
    }
    return IcuChoice(name[0]!, type[0]!, branches);
  }

  /// Braces that do not form an argument (`{ not an arg }`): keep as text.
  IcuNode literalBlock(int start) {
    var depth = 0;
    i = start;
    while (i < s.length) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) {
          i++;
          return IcuText(s.substring(start, i));
        }
      }
      i++;
    }
    throw const FormatException('unbalanced braces: a "{" is never closed');
  }
}
