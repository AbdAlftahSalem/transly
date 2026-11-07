import 'package:test/test.dart';
import 'package:transly/transly.dart';

void main() {
  group('readJson', () {
    test('keeps key order and nested values', () {
      final doc = readJson('{"b": 1, "a": {"y": "Y", "x": [true, null, 2.5]}}');
      final map = doc.value! as Map<String, Object?>;
      expect(map.keys, ['b', 'a']);
      expect((map['a']! as Map).keys, ['y', 'x']);
      expect((map['a']! as Map)['x'], [true, null, 2.5]);
    });

    test('decodes escapes and unicode', () {
      final doc = readJson(r'{"k": "a\"b\\c\n\u0645\u0631\u062d\u0628\u0627"}');
      expect((doc.value! as Map)['k'], 'a"b\\c\nمرحبا');
    });

    test('records key lines', () {
      final doc = readJson('{\n  "a": "1",\n  "b": {\n    "c": "2"\n  }\n}');
      expect(doc.keyLines, {'a': 2, 'b': 3, 'b.c': 4});
    });

    test('reports duplicate keys with both lines, last value wins', () {
      final doc = readJson('{\n  "a": "1",\n  "a": "2"\n}');
      expect(doc.duplicates, hasLength(1));
      expect(doc.duplicates.single.key, 'a');
      expect(doc.duplicates.single.line, 3);
      expect(doc.duplicates.single.firstLine, 2);
      expect((doc.value! as Map)['a'], '2');
    });

    test('duplicates in nested objects carry the path', () {
      final doc = readJson('{"x": {"a": 1, "a": 2}, "a": 3}');
      expect(doc.duplicates.map((d) => d.key), ['x.a']);
    });

    test('skips a BOM', () {
      expect((readJson('\uFEFF{"a": "b"}').value! as Map)['a'], 'b');
    });

    final bad = <String, (String, int, String)>{
      'missing comma': ('{\n  "a": "1"\n  "b": "2"\n}', 2, 'missing comma'),
      'trailing comma': ('{\n  "a": "1",\n}', 3, 'trailing comma'),
      'single quotes': ("{'a': 1}", 1, 'expected a "quoted" key'),
      'unterminated string': ('{"a": "abc', 1, 'unterminated'),
      'raw newline in string': ('{"a": "ab\ncd"}', 1, 'line break'),
      'empty file': ('   ', 1, 'empty'),
      'extra content': ('{} {}', 1, 'after the end'),
      'bad literal': ('{"a": tru}', 1, 'true'),
      'missing colon': ('{"a" 1}', 1, 'expected :'),
      'unclosed object': ('{"a": 1', 1, 'missing }'),
    };
    bad.forEach((name, c) {
      test('syntax error: $name', () {
        expect(
          () => readJson(c.$1),
          throwsA(isA<JsonSyntaxError>()
              .having((e) => e.line, 'line', c.$2)
              .having((e) => e.message, 'message', contains(c.$3))),
        );
      });
    });

    test('error column points at the problem', () {
      try {
        readJson('{"a": 1, "b": x}');
        fail('should throw');
      } on JsonSyntaxError catch (e) {
        expect(e.column, 15);
      }
    });
  });
}
