import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:transly/transly.dart';

import 'helpers.dart';
import 'translate_test.dart' show FakeEngine;

Future<(int, String, String)> cli(List<String> args,
    {Map<String, String> env = const {}, List<TranslationEngine>? engines}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runTransly(args, out: out, err: err, color: false, environment: env, engines: engines);
  return (code, out.toString(), err.toString());
}

void main() {
  test('--version', () async {
    final (code, out, _) = await cli(['--version']);
    expect(code, 0);
    expect(out.trim(), '$toolName $toolVersion');
  });

  test('version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $toolVersion'));
    expect(pubspec, contains('name: $toolName'));
  });

  test('no command means check, and options before it work', () async {
    final root = copyFixture('arb_app');
    final (code, out, _) = await cli(['-C', root]);
    expect(code, 0);
    expect(out, contains('base en (l10n.yaml template)'));
    expect(out, contains('✖ 6 errors  ▲ 8 warnings'));
  });

  test('check --ci fails on errors, --fail-on never does not', () async {
    final root = copyFixture('arb_app');
    expect((await cli(['check', '-C', root, '--ci'])).$1, 1);
    expect((await cli(['check', '-C', root, '--ci', '--fail-on', 'never'])).$1, 0);
  });

  test('check --ci passes on a clean project; --fail-on warning is stricter', () async {
    final root = Directory.systemTemp.createTempSync('transly_clean_').path;
    write(root, 'lib/l10n/app_en.arb', '{"hello": "Hello world"}');
    write(root, 'lib/l10n/app_ar.arb', '{"hello": "مرحبا بالعالم"}');
    write(root, 'lib/main.dart', "void f() { Text(l10n.hello); Text('Oops text'); }");
    expect((await cli(['check', '-C', root, '--ci'])).$1, 0);
    expect((await cli(['check', '-C', root, '--ci', '--fail-on', 'warning'])).$1, 1);
    expect((await cli(['check', '-C', root, '--ci', '--fail-on', 'warning', '--no-hardcoded'])).$1, 0);
  });

  test('check --json', () async {
    final root = copyFixture('json_app');
    final (code, out, _) = await cli(['check', '-C', root, '--json']);
    expect(code, 0);
    final data = jsonDecode(out) as Map<String, dynamic>;
    expect(data['base'], 'ar');
    expect(data['format'], 'json');
    final en = (data['locales'] as List).firstWhere((l) => l['locale'] == 'en') as Map;
    expect(en['counts'], containsPair('missing', 1));
    expect((data['issues'] as List).map((i) => i['kind']),
        containsAll(['unknown-key', 'wrong-args', 'unused', 'hardcoded']));
    expect(data['summary'], containsPair('errors', 6));
  });

  test('check --no-code skips the Dart checks', () async {
    final root = copyFixture('arb_app');
    final (_, out, _) = await cli(['check', '-C', root, '--no-code']);
    expect(out, isNot(contains('unknown-key')));
    expect(out, isNot(contains('Dart files')));
  });

  test('GitHub annotations with --ci on Actions', () async {
    final root = copyFixture('arb_app');
    final (_, out, _) = await cli(['check', '-C', root, '--ci'], env: {'GITHUB_ACTIONS': 'true'});
    expect(out,
        contains('::error file=lib/l10n/app_ar.arb,line=4,title=transly placeholder::[ar] welcome: {name} is missing'));
    expect(out, contains('::warning file=lib/main.dart,line=27,col=16,title=transly hardcoded::'));
  });

  test('fix --dry-run writes nothing and shows a diff', () async {
    final root = copyFixture('arb_app');
    final before = read(root, 'lib/l10n/app_ar.arb');
    final (code, out, _) = await cli(['fix', '-C', root, '--dry-run', '-l', 'ar']);
    expect(code, 0);
    expect(out, contains('+  "deleteAccount": "TODO: Delete account",'));
    expect(read(root, 'lib/l10n/app_ar.arb'), before);
  });

  test('fix writes, skips the file with duplicates, then ar is complete', () async {
    final root = copyFixture('arb_app');
    final (code, out, _) = await cli(['fix', '-C', root]);
    expect(code, 65); // fr has a duplicate key and is left alone
    expect(out, contains('skipped'));
    final (_, json, _) = await cli(['check', '-C', root, '--json', '--no-code']);
    final ar = (jsonDecode(json)['locales'] as List).firstWhere((l) => l['locale'] == 'ar') as Map;
    expect(ar['counts'], isNot(contains('missing')));
    expect(ar['counts'], containsPair('todo', 2));
  });

  test('add creates a locale (Arabic base → English)', () async {
    final root = copyFixture('json_app');
    write(root, 'assets/translations/en.json', '{}');
    File(p.join(root, 'assets/translations/en.json')).deleteSync();
    final (code, out, _) = await cli(['add', 'en', '-C', root, '--base', 'ar']);
    expect(code, 0, reason: out);
    final en = jsonDecode(read(root, 'assets/translations/en.json')) as Map<String, dynamic>;
    expect((en['home'] as Map)['title'], 'TODO: الرئيسية');
    expect(out, contains('Created assets/translations/en.json with 12 keys from ar'));
  });

  test('add refuses an existing file, --copy-base, --dry-run', () async {
    final root = copyFixture('arb_app');
    final (code, _, err) = await cli(['add', 'ar', '-C', root]);
    expect(code, 64);
    expect(err, contains('already exists'));
    final (c2, out, _) = await cli(['add', 'de', '-C', root, '--copy-base', '--dry-run']);
    expect(c2, 0);
    expect(out, contains('"settings": "Settings"'));
    expect(File(p.join(root, 'lib/l10n/app_de.arb')).existsSync(), isFalse);
  });

  test('add rejects a non-locale', () async {
    final (code, _, _) = await cli(['add', 'english', '-C', copyFixture('arb_app')]);
    expect(code, 64);
  });

  test('translate fills only missing/TODO values, marks them, check lists them', () async {
    final root = copyFixture('arb_app');
    final (code, out, _) = await cli(['translate', 'ar', '-C', root], engines: [FakeEngine()]);
    expect(code, 0, reason: out);
    final ar = jsonDecode(read(root, 'lib/l10n/app_ar.arb')) as Map<String, dynamic>;
    expect(ar['deleteAccount'], '[ar] DELETE ACCOUNT');
    expect(ar['signOut'], '[ar] SIGN OUT');
    expect(ar['@signOut'], {'x-translated': 'auto'});
    expect(ar['appTitle'], 'المتجر'); // untouched
    final review = jsonDecode(read(root, reviewFileName)) as Map<String, dynamic>;
    expect((review['locales'] as Map)['ar'], contains('deleteAccount'));
    final (_, check, _) = await cli(['check', '-C', root, '--no-code']);
    expect(check, contains('needs-review'));
  });

  test('translate --dry-run and new locale with plurals', () async {
    final root = copyFixture('arb_app');
    final (code, out, _) = await cli(['translate', 'de', '-C', root, '--dry-run'], engines: [FakeEngine()]);
    expect(code, 0);
    expect(out, contains('Dry run'));
    expect(File(p.join(root, 'lib/l10n/app_de.arb')).existsSync(), isFalse);
    await cli(['translate', 'de', '-C', root], engines: [FakeEngine()]);
    final de = jsonDecode(read(root, 'lib/l10n/app_de.arb')) as Map<String, dynamic>;
    expect(de['@@locale'], 'de');
    expect(parseIcu(de['cartItems'] as String).error, isNull);
    expect(de['@cartItems'], {
      'placeholders': {
        'count': {'type': 'int'}
      },
      'x-translated': 'auto'
    });
  });

  test('translate --overwrite and --keys', () async {
    final root = copyFixture('arb_app');
    await cli(['translate', 'ar', '-C', root, '--overwrite', '-k', 'app*'], engines: [FakeEngine()]);
    final ar = jsonDecode(read(root, 'lib/l10n/app_ar.arb')) as Map<String, dynamic>;
    expect(ar['appTitle'], '[ar] SHOP');
    expect(ar['signOut'], 'TODO: Sign out');
  });

  test('unused and hardcoded commands', () async {
    final root = copyFixture('arb_app');
    final (c1, o1, _) = await cli(['unused', '-C', root, '--ci']);
    expect(c1, 1);
    expect(o1, contains('unusedBanner'));
    final (c2, o2, _) = await cli(['hardcoded', '-C', root, '--json']);
    expect(c2, 0);
    expect((jsonDecode(o2)['issues'] as List), hasLength(3));
  });

  test('hardcoded works in a project without translations', () async {
    final root = Directory.systemTemp.createTempSync('transly_hc_').path;
    write(root, 'lib/main.dart', "Widget f() => Text('Hello there');");
    final (code, out, _) = await cli(['hardcoded', '-C', root]);
    expect(code, 0);
    expect(out, contains('"Hello there" is not localized'));
  });

  test('init writes transly.yaml', () async {
    final root = copyFixture('arb_app');
    final (code, _, _) = await cli(['init', '-C', root]);
    expect(code, 0);
    final cfg = TranslyConfig.fromYaml(read(root, configFileName));
    expect(cfg.dir, 'lib/l10n');
    expect(cfg.base, 'en');
    expect((await cli(['init', '-C', root])).$1, 64);
  });

  test('broken base is a clear error for fix', () async {
    final root = Directory.systemTemp.createTempSync('transly_bb_').path;
    write(root, 'lib/l10n/app_en.arb', '{"a": }');
    write(root, 'lib/l10n/app_fr.arb', '{"a": "b"}');
    final (code, _, err) = await cli(['fix', '-C', root]);
    expect(code, 65);
    expect(err, contains('not valid JSON'));
  });

  test('no translations folder: exit 66 with a hint', () async {
    final root = Directory.systemTemp.createTempSync('transly_empty_').path;
    final (code, _, err) = await cli(['check', '-C', root]);
    expect(code, 66);
    expect(err, contains('--dir'));
  });

  test('bad usage: exit 64', () async {
    expect((await cli(['check', '--nope'])).$1, 64);
    expect((await cli(['check', '--fail-on', 'sometimes'])).$1, 64);
  });
}
