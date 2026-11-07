import 'package:test/test.dart';
import 'package:transly/transly.dart';

import 'helpers.dart';

DartSource src(String code, [String name = 'lib/x.dart']) => DartSource('/p/$name', name, code);

void main() {
  group('scanDart', () {
    test('finds strings and masks them', () {
      final s = scanDart("var a = 'x' + \"y\"; // 'not a string'\n/* 'nor this' */ r'raw\\n';");
      expect(s.strings.map((x) => x.value), ['x', 'y', r'raw\n']);
      expect(s.masked, isNot(contains('not a string')));
      expect(s.masked.length, s.source.length);
      expect(s.comments, hasLength(2));
    });

    test('interpolation and nested strings', () {
      final s = scanDart(r"""var a = 'errors.$code'; var b = "hi ${name.toUpperCase('x')}!";""");
      final a = s.strings.firstWhere((x) => x.value.startsWith('errors'));
      expect(a.interpolated, isTrue);
      expect(a.staticPrefix, 'errors.');
      expect(s.strings.map((x) => x.value), contains('x'));
    });

    test('triple quoted and escapes', () {
      final s = scanDart("var a = '''line1\nline2'''; var b = 'it\\'s';");
      expect(s.strings.map((x) => x.value), ['line1\nline2', "it's"]);
      expect(s.lineOf(s.strings.last.start), 2);
    });

    test('nested block comments', () {
      final s = scanDart("/* a /* b */ 'c' */ var x = 'd';");
      expect(s.strings.map((x) => x.value), ['d']);
    });

    test('ignore markers: same line and line above', () {
      final s = scanDart('a(); // transly:ignore\n// transly:ignore\nb();\nc();');
      expect(s.isIgnored(1, ignoreMarker), isTrue);
      expect(s.isIgnored(3, ignoreMarker), isTrue);
      expect(s.isIgnored(4, ignoreMarker), isFalse);
    });

    test('matchingBracket and splitTopLevel', () {
      const code = 'f(a, g(b, c), [d, e], {f: 1},)';
      final close = matchingBracket(code, 1);
      expect(close, code.length - 1);
      expect(splitTopLevel(code.substring(2, close)), hasLength(4));
    });
  });

  group('hardcoded strings', () {
    List<String> found(String code) => [for (final i in findHardcodedStrings(src(code))) i.message];

    test('Text, named params, Arabic', () {
      const code = '''
Widget b() => Column(children: [
  Text('Buy now'),
  const Text("Sign in"),
  SelectableText('Copy me'),
  TextField(decoration: InputDecoration(hintText: 'Search', labelText: 'Name')),
  IconButton(tooltip: 'Share', onPressed: null, icon: x),
  Text('حفظ'),
  TextSpan(text: 'Read more'),
]);
''';
      expect(found(code), [
        '"Buy now" is not localized',
        '"Sign in" is not localized',
        '"Copy me" is not localized',
        '"Search" is not localized',
        '"Name" is not localized',
        '"Share" is not localized',
        '"حفظ" is not localized',
        '"Read more" is not localized',
      ]);
    });

    test('skips localized, non-text and ignored strings', () {
      const code = '''
Widget b() => Column(children: [
  Text('home.title'.tr()),
  Text(tr('home.title')),
  Text(l10n.title),
  Text('\${l10n.count} 42'),
  Image.asset('assets/logo.png'),
  Text('assets/images/x.png'),
  Text('https://example.com'),
  Text('Skip me'), // transly:ignore
  // transly:ignore
  Text('Skip me too'),
  Text('   '),
  Text('123'),
  print('Debug message'),
  Key('login_button'),
]);
''';
      expect(found(code), isEmpty);
    });

    test('a key used as plain text gets a hint', () {
      final issues = findHardcodedStrings(src("Text('home.title')"), knownKeys: {'home.title'});
      expect(issues.single.message, contains('missing .tr()'));
    });

    test('ignore-file', () {
      expect(found("// transly:ignore-file\nText('A sentence')"), isEmpty);
    });

    test('line and column', () {
      final i = findHardcodedStrings(src("\n\n  Text('Hello there')")).single;
      expect(i.line, 3);
      expect(i.column, 8);
    });
  });

  group('arb_app code check', () {
    late CodeReport report;
    late TranslyProject pr;
    setUpAll(() {
      pr = TranslyProject.load(root: copyFixture('arb_app'));
      report = checkCode(pr.base, collectDartSources(pr.root, ['lib'], generatedDir: pr.dir));
    });

    test('the generated localizations file is skipped', () {
      expect(report.filesScanned, 1);
    });

    test('typo is an unknown key with a suggestion', () {
      final i = report.issues.firstWhere((i) => i.kind == IssueKind.unknownKey);
      expect(i.key, 'setings');
      expect(i.message, contains('did you mean "settings"'));
      expect(i.file, 'lib/main.dart');
      expect(i.line, 24);
    });

    test('wrong number of arguments', () {
      final i = report.issues.where((i) => i.kind == IssueKind.wrongArguments).toList();
      expect(i, hasLength(1));
      expect(i.single.message, '"welcome" takes 1 ({name}) but 0 are passed');
    });

    test('right arguments pass (welcome(name), cartItems(n), greeting(g, n))', () {
      expect(report.references.where((r) => r.key == 'greeting').single.positionalArgs, 2);
    });

    test('unused: only the planted key', () {
      expect([
        for (final i in report.issues)
          if (i.kind == IssueKind.unusedKey) i.key
      ], [
        'unusedBanner'
      ]);
    });

    test('hardcoded: Buy now, Share, Search products', () {
      expect([
        for (final i in report.issues)
          if (i.kind == IssueKind.hardcodedString) i.line
      ], [
        27,
        33,
        34
      ]);
    });
  });

  group('json_app code check', () {
    late CodeReport report;
    setUpAll(() {
      final pr = TranslyProject.load(root: copyFixture('json_app'));
      report = checkCode(pr.base, collectDartSources(pr.root, ['lib']));
    });

    List<String> of(IssueKind k) => [
          for (final i in report.issues)
            if (i.kind == k) '${i.key}@${i.line}'
        ];

    test('unknown key with suggestion', () {
      expect(of(IssueKind.unknownKey), ['home.welcom@18']);
    });

    test('namedArgs and args checks', () {
      expect(of(IssueKind.wrongArguments), ['home.welcome@19', 'profile.edit@20']);
    });

    test('dynamic keys and plural parents count as used', () {
      expect(of(IssueKind.unusedKey), ['unused_tip@23']);
    });

    test('hardcoded in a JSON project', () {
      expect(of(IssueKind.hardcodedString).length, 2);
    });
  });

  test('custom accessor and output-class', () {
    final base = TranslationFile.parse('app_en.arb', '{"hello": "Hello", "bye": "Bye {name}"}');
    final code = src('void f() { t.hello; t.byee; Strings.of(context).bye(1, 2); }');
    final r = checkCode(base, [code],
        const CodeCheckOptions(accessors: ['t'], outputClass: 'Strings', unused: false, hardcoded: false));
    expect([for (final i in r.issues) i.kind], [IssueKind.unknownKey, IssueKind.wrongArguments]);
  });

  test('ignore marker silences a reference', () {
    final base = TranslationFile.parse('app_en.arb', '{"hello": "Hello"}');
    final code = src('void f() { l10n.nope; // transly:ignore\n }');
    expect(checkCode(base, [code]).issues.where((i) => i.kind == IssueKind.unknownKey), isEmpty);
  });

  test('members like localeName are not keys', () {
    final base = TranslationFile.parse('app_en.arb', '{"hello": "Hello"}');
    final code = src('void f() { l10n.localeName; l10n.hello; }');
    expect(checkCode(base, [code]).issues, isEmpty);
  });

  test('LocaleKeys constants count as usage', () {
    final base = TranslationFile.parse('en.json', '{"home": {"title": "Home"}}');
    final code = src('void f() { LocaleKeys.home_title.tr(); }');
    expect(usedKeys(base, [code]), {'home.title'});
  });
}
