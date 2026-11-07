/// Creating and fixing translation files without losing data.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'translation_file.dart';

/// What to put in a value that has no translation yet.
enum FillMode {
  /// An empty string.
  empty,

  /// `TODO: <base text>`, easy to spot in the app and in `check`.
  todo,

  /// The base text itself.
  base;

  /// Parses `empty` / `todo` / `base`.
  static FillMode parse(String value) => FillMode.values.firstWhere((m) => m.name == value);
}

/// The value written for a key that has no translation yet.
Object? fillValue(FillMode mode, Object? baseValue) {
  if (baseValue is! String) return mode == FillMode.base ? baseValue : (mode == FillMode.todo ? 'TODO' : '');
  return switch (mode) {
    FillMode.empty => '',
    FillMode.todo => 'TODO: $baseValue',
    FillMode.base => baseValue,
  };
}

/// A planned change to one file.
class FilePlan {
  /// Creates a plan.
  const FilePlan(
      {required this.path,
      required this.before,
      required this.after,
      this.added = const [],
      this.removed = const [],
      this.updated = const [],
      this.created = false});

  /// The file to write.
  final String path;

  /// The current content (empty when the file is new).
  final String before;

  /// The new content.
  final String after;

  /// Keys added.
  final List<String> added;

  /// Keys removed.
  final List<String> removed;

  /// Keys whose value changed.
  final List<String> updated;

  /// Whether the file is new.
  final bool created;

  /// Whether anything changes.
  bool get changed => before != after;

  /// Whether only the key order changes.
  bool get reorderedOnly => changed && added.isEmpty && removed.isEmpty && updated.isEmpty;

  /// Writes [after] to [path] (through a temporary file, then a rename).
  void write() {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final tmp = File('$path.transly.tmp');
    tmp.writeAsStringSync(after);
    tmp.renameSync(path);
  }
}

/// Encodes [value] like the source file: same indent, a trailing line break.
String encodeJson(Object? value, {String indent = '  ', bool trailingNewline = true, String lineEnding = '\n'}) {
  var text = JsonEncoder.withIndent(indent).convert(value);
  if (trailingNewline) text = '$text\n';
  return lineEnding == '\n' ? text : text.replaceAll('\n', lineEnding);
}

/// Plans `fix` for [target]: every base key in base order, existing values
/// kept, missing keys filled with [fill], keys missing from the base kept at
/// the end (or dropped with [removeExtra]). [overrides] replaces values
/// (used by `translate`). Metadata is kept; for new keys the base metadata
/// is copied. [metadataExtra] adds attributes to a key's ARB metadata.
FilePlan planFix(
  TranslationFile base,
  TranslationFile target, {
  FillMode fill = FillMode.todo,
  bool removeExtra = false,
  Map<String, String> overrides = const {},
  Map<String, Map<String, Object?>> metadataExtra = const {},
  String? indent,
  bool? trailingNewline,
  String? lineEnding,
}) {
  if (!target.isValid) throw StateError('${target.fileName} is not valid JSON; fix it by hand first');
  if (target.duplicates.isNotEmpty) {
    throw StateError(
        '${target.fileName} has duplicate keys (${target.duplicates.map((d) => d.key).join(', ')}); remove them by hand first');
  }
  final added = <String>[];
  final removed = <String>[];
  final updated = <String>[];
  final ordered = <MapEntry<List<String>, Object?>>[];
  final meta = <String, Object?>{};

  for (final key in base.entries.keys) {
    final path = target.keyPaths[key] ?? base.keyPaths[key] ?? [key];
    Object? value;
    if (target.entries.containsKey(key)) {
      value = target.entries[key];
      if (target.metadata.containsKey(key)) meta[key] = target.metadata[key];
    } else {
      value = fillValue(fill, base.entries[key]);
      added.add(key);
      if (base.metadata.containsKey(key)) meta[key] = _deepCopy(base.metadata[key]);
    }
    final o = overrides[key];
    if (o != null && o != value) {
      value = o;
      if (!added.contains(key)) updated.add(key);
    }
    final extra = metadataExtra[key];
    if (extra != null && base.format == TranslationFormat.arb) {
      final m = meta[key] is Map
          ? Map<String, Object?>.from(meta[key]! as Map)
          : (base.metadata[key] is Map ? Map<String, Object?>.from(base.metadata[key]! as Map) : <String, Object?>{});
      m.addAll(extra);
      meta[key] = m;
    }
    ordered.add(MapEntry(path, value));
  }
  for (final key in target.entries.keys) {
    if (base.entries.containsKey(key)) continue;
    if (removeExtra) {
      removed.add(key);
    } else {
      ordered.add(MapEntry(target.keyPaths[key] ?? [key], target.entries[key]));
      if (target.metadata.containsKey(key)) meta[key] = target.metadata[key];
    }
  }
  // Metadata whose message is gone (an orphan "@key").
  for (final key in target.metadata.keys) {
    if (target.entries.containsKey(key) || meta.containsKey(key)) continue;
    if (!removeExtra) meta[key] = target.metadata[key];
  }

  final Object out;
  if (target.format == TranslationFormat.arb) {
    final map = <String, Object?>{...target.globals};
    for (final e in ordered) {
      final key = e.key.single;
      map[key] = e.value;
      if (meta.containsKey(key)) map['@$key'] = meta.remove(key);
    }
    meta.forEach((k, v) => map['@$k'] = v);
    out = map;
  } else {
    final nested = target.entries.isEmpty ? base.nested : target.nested;
    out = nested ? unflatten(ordered) : {for (final e in ordered) e.key.join('.'): e.value};
  }
  final after = encodeJson(out,
      indent: indent ?? target.indent,
      trailingNewline: trailingNewline ?? target.endsWithNewline,
      lineEnding: lineEnding ?? target.lineEnding);
  return FilePlan(
      path: target.path, before: target.source, after: after, added: added, removed: removed, updated: updated);
}

/// Plans a new file for [locale] next to [base], named like it
/// (`app_en.arb` → `app_fr.arb`, `en.json` → `fr.json`), with every base key
/// in order, ARB metadata copied, and values filled with [fill].
FilePlan planNewLocale(TranslationFile base, String locale,
    {FillMode fill = FillMode.todo,
    Map<String, String> overrides = const {},
    Map<String, Map<String, Object?>> metadataExtra = const {}}) {
  final path = pathForLocale(base, locale);
  final seed = base.format == TranslationFormat.arb ? '{"@@locale": ${jsonEncode(locale)}}' : '{}';
  final target = TranslationFile.parse(path, seed, format: base.format);
  final plan = planFix(base, target,
      fill: fill,
      overrides: overrides,
      metadataExtra: metadataExtra,
      indent: base.indent,
      trailingNewline: true,
      lineEnding: base.lineEnding);
  return FilePlan(path: path, before: '', after: plan.after, added: plan.added, created: true);
}

/// The file name a new [locale] gets, following the base file's pattern.
String pathForLocale(TranslationFile base, String locale) {
  final name = p.basenameWithoutExtension(base.path);
  final ext = p.extension(base.path);
  final fl = base.fileLocale;
  final newName = fl == null
      ? '${name}_$locale'
      : '${name.substring(0, fl.start)}$locale${name.substring(fl.start + fl.locale.length)}';
  return p.join(p.dirname(base.path), '$newName$ext');
}

/// Rebuilds nested JSON objects from `(path, value)` pairs, keeping order.
Map<String, Object?> unflatten(List<MapEntry<List<String>, Object?>> entries) {
  final root = <String, Object?>{};
  for (final e in entries) {
    var node = root;
    final path = e.key;
    var placed = false;
    for (var i = 0; i < path.length - 1; i++) {
      final next = node[path[i]];
      if (next == null) {
        final created = <String, Object?>{};
        node[path[i]] = created;
        node = created;
      } else if (next is Map<String, Object?>) {
        node = next;
      } else {
        // A value already sits where an object is needed: keep a dotted key.
        node[path.sublist(i).join('.')] = e.value;
        placed = true;
        break;
      }
    }
    if (!placed) node[path.last] = e.value;
  }
  return root;
}

Object? _deepCopy(Object? v) {
  if (v is Map) return {for (final e in v.entries) '${e.key}': _deepCopy(e.value)};
  if (v is List) return [for (final x in v) _deepCopy(x)];
  return v;
}

/// A compact unified diff of two texts (line based), for `--dry-run`.
List<String> unifiedDiff(String before, String after,
    {String fromName = 'before', String toName = 'after', int context = 2}) {
  final a = before.isEmpty ? <String>[] : before.split('\n');
  final b = after.isEmpty ? <String>[] : after.split('\n');
  if (a.isNotEmpty && a.last.isEmpty) a.removeLast();
  if (b.isNotEmpty && b.last.isEmpty) b.removeLast();
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length;
  var endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  // ops over the middle: ' ' keep, '-' delete, '+' insert
  final ops = <MapEntry<String, String>>[];
  final ma = a.sublist(start, endA);
  final mb = b.sublist(start, endB);
  if (ma.length * mb.length > 4000000) {
    ops.addAll(ma.map((l) => MapEntry('-', l)));
    ops.addAll(mb.map((l) => MapEntry('+', l)));
  } else {
    final lcs = List.generate(ma.length + 1, (_) => List<int>.filled(mb.length + 1, 0));
    for (var i = ma.length - 1; i >= 0; i--) {
      for (var j = mb.length - 1; j >= 0; j--) {
        lcs[i][j] =
            ma[i] == mb[j] ? lcs[i + 1][j + 1] + 1 : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    while (i < ma.length || j < mb.length) {
      if (i < ma.length && j < mb.length && ma[i] == mb[j]) {
        ops.add(MapEntry(' ', ma[i]));
        i++;
        j++;
      } else if (j < mb.length && (i >= ma.length || lcs[i][j + 1] >= lcs[i + 1][j])) {
        ops.add(MapEntry('+', mb[j]));
        j++;
      } else {
        ops.add(MapEntry('-', ma[i]));
        i++;
      }
    }
  }
  if (ops.every((o) => o.key == ' ')) return const [];
  final all = [
    for (var k = 0; k < start; k++) MapEntry(' ', a[k]),
    ...ops,
    for (var k = endA; k < a.length; k++) MapEntry(' ', a[k]),
  ];
  final out = <String>['--- $fromName', '+++ $toName'];
  final changed = [
    for (var k = 0; k < all.length; k++)
      if (all[k].key != ' ') k
  ];
  var k = 0;
  while (k < changed.length) {
    final from = (changed[k] - context).clamp(0, all.length);
    var to = changed[k];
    while (k + 1 < changed.length && changed[k + 1] - to <= context * 2 + 1) {
      k++;
      to = changed[k];
    }
    final end = (to + context + 1).clamp(0, all.length);
    final lineA = all.sublist(0, from).where((o) => o.key != '+').length + 1;
    final lineB = all.sublist(0, from).where((o) => o.key != '-').length + 1;
    final hunk = all.sublist(from, end);
    out.add(
        '@@ -$lineA,${hunk.where((o) => o.key != '+').length} +$lineB,${hunk.where((o) => o.key != '-').length} @@');
    for (var x = from; x < end; x++) {
      out.add('${all[x].key}${all[x].value}');
    }
    k++;
  }
  return out;
}
