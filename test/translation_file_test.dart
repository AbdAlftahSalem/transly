import 'package:test/test.dart';
import 'package:transly/transly.dart';

void main() {
  test('ARB: messages, metadata and globals are separated', () {
    final f = TranslationFile.parse(
        'lib/l10n/app_en.arb', '{"@@locale": "en", "a": "A", "@a": {"description": "x"}, "b": "B {n}"}');
    expect(f.format, TranslationFormat.arb);
    expect(f.locale, 'en');
    expect(f.entries, {'a': 'A', 'b': 'B {n}'});
    expect(f.metadata.keys, ['a']);
    expect(f.globals, {'@@locale': 'en'});
  });

  test('ARB: @@locale wins over the file name', () {
    expect(TranslationFile.parse('intl_messages_x.arb', '{"@@locale": "de"}').locale, 'de');
  });

  test('JSON: nested keys are flattened with dots, order kept', () {
    final f = TranslationFile.parse('en.json', '{"home": {"title": "Home", "sub": {"x": "X"}}, "about": "About"}');
    expect(f.entries.keys, ['home.title', 'home.sub.x', 'about']);
    expect(f.nested, isTrue);
    expect(f.keyPaths['home.sub.x'], ['home', 'sub', 'x']);
  });

  test('JSON: flat dotted keys stay flat', () {
    final f = TranslationFile.parse('en.json', '{"home.title": "Home"}');
    expect(f.nested, isFalse);
    expect(f.entries.keys, ['home.title']);
  });

  test('indent and trailing newline are detected', () {
    final f = TranslationFile.parse('en.json', '{\n    "a": "b"\n}');
    expect(f.indent, '    ');
    expect(f.endsWithNewline, isFalse);
  });

  test('invalid JSON is reported, not thrown', () {
    final f = TranslationFile.parse('en.json', '{"a": "b",}');
    expect(f.isValid, isFalse);
    expect(f.error!.message, contains('trailing comma'));
  });

  test('top level must be an object', () {
    expect(TranslationFile.parse('en.json', '["a"]').error!.message, contains('top level'));
  });

  test('line of a nested key', () {
    final f = TranslationFile.parse('en.json', '{\n  "a": {\n    "b": "c"\n  }\n}');
    expect(f.lineOf('a.b'), 3);
  });
}
