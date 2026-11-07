import 'package:test/test.dart';
import 'package:transly/transly.dart';

import 'helpers.dart';

TranslationFile arb(String name, String json) => TranslationFile.parse('lib/l10n/$name', json);

void main() {
  group('arb_app fixture', () {
    late List<LocaleReport> reports;
    LocaleReport of(String l) => reports.firstWhere((r) => r.locale == l);
    List<String> ids(String l) => [for (final i in of(l).issues) '${i.kind.id}:${i.key}'];

    setUpAll(() {
      final pr = TranslyProject.load(root: copyFixture('arb_app'));
      reports = checkFiles(pr.base, pr.targets, CheckOptions(displayPath: pr.relative));
    });

    test('base is clean and first', () {
      expect(reports.first.isBase, isTrue);
      expect(reports.first.issues, isEmpty);
      expect(reports.first.coverage, 1);
    });

    test('ar: exactly the planted problems', () {
      expect(
          ids('ar'),
          unorderedEquals([
            'placeholder:welcome',
            'untranslated:settings',
            'todo:signOut',
            'missing:deleteAccount',
            'extra:oldKey',
          ]));
    });

    test('ar: plural with more categories than English is fine', () {
      expect(ids('ar').where((x) => x.endsWith(':cartItems')), isEmpty);
    });

    test('fr: duplicate, plural without other, empty', () {
      expect(ids('fr'), unorderedEquals(['duplicate-key:signOut', 'placeholder:cartItems', 'empty:unusedBanner']));
    });

    test('fr: "OK" equal to the base is not flagged (too short)', () {
      expect(ids('fr'), isNot(contains('untranslated:ok')));
    });

    test('issues carry file and line', () {
      final i = of('ar').issues.firstWhere((i) => i.key == 'welcome');
      expect(i.file, 'lib/l10n/app_ar.arb');
      expect(i.line, 4);
      expect(i.severity, Severity.error);
    });

    test('coverage counts only real translations', () {
      // 9 keys: deleteAccount missing, signOut TODO, settings same as base.
      expect(of('ar').translated, 6);
      expect(of('ar').coverage, closeTo(6 / 9, 0.001));
    });
  });

  test('json_app: nested keys, positional and named placeholders, ignore_untranslated', () {
    final pr = TranslyProject.load(root: copyFixture('json_app'));
    final reports = checkFiles(pr.base, pr.targets, CheckOptions(ignoreUntranslated: pr.config.ignoreUntranslated!));
    final en = reports.last;
    expect(
        [for (final i in en.issues) '${i.kind.id}:${i.key}'],
        unorderedEquals([
          'placeholder:home.welcome',
          'placeholder:home.welcome',
          'missing:profile.edit',
          'untranslated:about',
          'extra:legacy',
        ]));
  });

  test('broken files: invalid JSON and ICU syntax', () {
    final pr = TranslyProject.load(root: copyFixture('broken_app'));
    final reports = checkFiles(pr.base, pr.targets);
    final de = reports.firstWhere((r) => r.locale == 'de');
    expect(de.issues.single.kind, IssueKind.invalidJson);
    expect(de.issues.single.line, 2);
    final es = reports.firstWhere((r) => r.locale == 'es');
    expect(es.issues.single.kind, IssueKind.icuSyntax);
  });

  test('ignore keys skip every check', () {
    final base = arb('app_en.arb', '{"a": "Alpha text", "b": "Beta text"}');
    final fr = arb('app_fr.arb', '{"x": "X"}');
    final r = checkFiles(base, [fr], const CheckOptions(ignoreKeys: ['a', 'x'])).last;
    expect([for (final i in r.issues) i.key], ['b']);
  });

  test('same language variants are not "untranslated"', () {
    final base = arb('app_en.arb', '{"a": "Colour settings"}');
    final gb = arb('app_en_GB.arb', '{"a": "Colour settings"}');
    expect(checkFiles(base, [gb]).last.issues, isEmpty);
  });

  test('--no-identical', () {
    final base = arb('app_en.arb', '{"a": "Colour settings"}');
    final de = arb('app_de.arb', '{"a": "Colour settings"}');
    expect(checkFiles(base, [de]).last.issues.single.kind, IssueKind.untranslated);
    expect(checkFiles(base, [de], const CheckOptions(checkIdentical: false)).last.issues, isEmpty);
  });

  test('isWorthTranslating', () {
    expect(isWorthTranslating('Settings'), isTrue);
    expect(isWorthTranslating('OK'), isFalse);
    expect(isWorthTranslating('API'), isFalse);
    expect(isWorthTranslating('{count}'), isFalse);
    expect(isWorthTranslating('https://example.com'), isFalse);
    expect(isWorthTranslating('42 %'), isFalse);
    expect(isWorthTranslating('{n, plural, one{x} other{y}}'), isTrue);
  });

  test('locale mismatch between @@locale and file name', () {
    final base = arb('app_en.arb', '{"a": "A"}');
    final f = arb('app_fr.arb', '{"@@locale": "de", "a": "B"}');
    expect(checkFiles(base, [f]).last.issues.single.kind, IssueKind.localeMismatch);
  });

  test('machine translations awaiting review are info', () {
    final base = arb('app_en.arb', '{"a": "Hello there"}');
    final ar = arb('app_ar.arb', '{"a": "مرحبا هناك", "@a": {"x-translated": "auto"}}');
    final issues = checkFiles(base, [ar]).last.issues;
    expect(issues.single.kind, IssueKind.needsReview);
    expect(issues.single.severity, Severity.info);
    final edited = checkFiles(
        base,
        [ar],
        const CheckOptions(machineTranslated: {
          'ar': {'a': 'something else'}
        })).last.issues;
    expect(edited, isEmpty);
  });

  test('base problems are reported on the base', () {
    final base = arb('app_en.arb', '{"a": "", "b": "TODO later", "c": "{n, plural, one{x}}"}');
    final r = checkFiles(base, const []).single;
    expect([for (final i in r.issues) i.kind], [IssueKind.emptyValue, IssueKind.todoValue, IssueKind.icuSyntax]);
  });
}
