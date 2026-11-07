// Runs the compiled transly executable as a real process against the
// example apps (clean) and the broken copies in test/fixtures, and checks
// exit codes, output and the files it writes.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

late String exe;

Future<ProcessResult> transly(List<String> args, {Map<String, String>? env}) =>
    Process.run(exe, args, environment: {'NO_COLOR': '1', ...?env}, stdoutEncoding: utf8, stderrEncoding: utf8);

Future<Map<String, dynamic>> checkJson(String root, [List<String> extra = const []]) async {
  final r = await transly(['check', '-C', root, '--json', ...extra]);
  return jsonDecode(r.stdout as String) as Map<String, dynamic>;
}

Set<String> issueIds(Map<String, dynamic> report, {bool withInfo = false}) => {
      for (final i in report['issues'] as List)
        if (withInfo || i['severity'] != 'info') '${i['kind']} ${i['locale'] ?? '-'} ${i['key'] ?? i['line']}',
    };

Map<String, String> snapshot(String root) => {
      for (final f in Directory(root).listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: root): f.readAsStringSync(),
    };

String example(String name) => p.join(Directory.current.path, 'example', name);

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('transly_exe_').path;
    exe = p.join(dir, Platform.isWindows ? 'transly.exe' : 'transly');
    final r = await Process.run(Platform.resolvedExecutable, ['compile', 'exe', 'bin/transly.dart', '-o', exe]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  group('clean examples', () {
    test('shop_arb (gen-l10n, 168 keys, 5 locales) passes --ci --fail-on warning', () async {
      final r = await transly(['check', '-C', example('shop_arb'), '--ci', '--fail-on', 'warning']);
      expect(r.exitCode, 0, reason: r.stdout as String);
      expect(r.stdout, contains('168 keys  ·  5 locales'));
      expect(r.stdout, contains('All good.'));
    });

    test('shop_json (easy_localization, Arabic base) passes --ci --fail-on warning', () async {
      final r = await transly(['check', '-C', example('shop_json'), '--ci', '--fail-on', 'warning']);
      expect(r.exitCode, 0, reason: r.stdout as String);
      expect(r.stdout, contains('base ar (transly.yaml)'));
    });

    test('unused and hardcoded find nothing in the clean examples', () async {
      for (final name in ['shop_arb', 'shop_json']) {
        expect((await transly(['unused', '-C', example(name), '--ci'])).exitCode, 0, reason: name);
        expect((await transly(['hardcoded', '-C', example(name), '--ci'])).exitCode, 0, reason: name);
      }
    });
  });

  group('shop_arb_broken', () {
    test('check finds exactly the planted problems', () async {
      final report = await checkJson(copyFixture('shop_arb_broken'));
      expect(issueIds(report), {
        'todo ar wishlist',
        'untranslated ar settingsTitle',
        'untranslated ar helpCenter',
        'empty ar contactUs',
        'duplicate-key de signOut',
        'placeholder es welcomeBack',
        'placeholder es cartItems',
        'extra es legacyBanner',
        'missing fr checkoutTitle',
        'missing fr paymentFailed',
        'missing fr reorder',
        'unknown-key - chekoutTitle',
        'wrong-args - orderNumber',
        'unused en checkoutTitle',
        'unused en rateApp',
        'hardcoded - 212',
        'hardcoded - 213',
        'hardcoded - 214',
      });
      expect(report['summary'], {'errors': 9, 'warnings': 10, 'info': 0, 'failed': false});
    });

    test('--ci exits 1, with GitHub annotations', () async {
      final r = await transly(['check', '-C', copyFixture('shop_arb_broken'), '--ci'], env: {'GITHUB_ACTIONS': 'true'});
      expect(r.exitCode, 1);
      expect(r.stdout, contains('::error file=lib/l10n/app_fr.arb,title=transly missing::[fr] checkoutTitle: missing'));
      expect(r.stdout, contains('::error file=lib/sections.dart,line=146,'));
    });

    test('fix --dry-run changes nothing', () async {
      final root = copyFixture('shop_arb_broken');
      final before = snapshot(root);
      final r = await transly(['fix', '-C', root, '--dry-run']);
      expect(r.stdout, contains('+  "checkoutTitle": "TODO: Checkout",'));
      expect(snapshot(root), before);
    });

    test('fix adds the missing keys, skips the file with a duplicate, keeps everything else', () async {
      final root = copyFixture('shop_arb_broken');
      final frBefore = jsonDecode(read(root, 'lib/l10n/app_fr.arb')) as Map<String, dynamic>;
      final deBefore = read(root, 'lib/l10n/app_de.arb');
      final r = await transly(['fix', '-C', root]);
      expect(r.exitCode, 65);
      expect(r.stdout, contains('de'));
      expect(r.stdout, contains('skipped'));
      expect(read(root, 'lib/l10n/app_de.arb'), deBefore);
      final fr = jsonDecode(read(root, 'lib/l10n/app_fr.arb')) as Map<String, dynamic>;
      expect(fr['checkoutTitle'], 'TODO: Checkout');
      frBefore.forEach((k, v) => expect(fr[k], v, reason: k));
      final en = jsonDecode(read(root, 'lib/l10n/app_en.arb')) as Map<String, dynamic>;
      expect(fr.keys.where((k) => !k.startsWith('@')).toList(), en.keys.where((k) => !k.startsWith('@')).toList());
      final es = jsonDecode(read(root, 'lib/l10n/app_es.arb')) as Map<String, dynamic>;
      expect(es['legacyBanner'], 'Oferta antigua');
      final after = await checkJson(root);
      expect(issueIds(after).where((i) => i.startsWith('missing')), isEmpty);
      expect(issueIds(after), contains('todo fr checkoutTitle'));
    });

    test('fix --remove-extra', () async {
      final root = copyFixture('shop_arb_broken');
      await transly(['fix', '-C', root, '--remove-extra', '-l', 'es']);
      expect(jsonDecode(read(root, 'lib/l10n/app_es.arb')), isNot(contains('legacyBanner')));
    });

    test('add it creates a complete Italian file', () async {
      final root = copyFixture('shop_arb_broken');
      final r = await transly(['add', 'it', '-C', root]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final it = jsonDecode(read(root, 'lib/l10n/app_it.arb')) as Map<String, dynamic>;
      expect(it['@@locale'], 'it');
      expect(it.keys.where((k) => !k.startsWith('@')), hasLength(168));
      expect(it['onlyLeft'], startsWith('TODO: {count, plural,'));
      final report = await checkJson(root);
      final itRow = (report['locales'] as List).firstWhere((l) => l['locale'] == 'it') as Map;
      expect(itRow['counts'], {'todo': 168});
    });

    test('unused and hardcoded commands', () async {
      final root = copyFixture('shop_arb_broken');
      final u = await transly(['unused', '-C', root, '--ci']);
      expect(u.exitCode, 1);
      expect(u.stdout, contains('2 unused of 168 keys'));
      final h = await transly(['hardcoded', '-C', root, '--json']);
      expect((jsonDecode(h.stdout as String)['issues'] as List).map((i) => i['line']), [212, 213, 214]);
    });

    test('init then check uses transly.yaml', () async {
      final root = copyFixture('shop_arb_broken');
      File(p.join(root, 'transly.yaml')).deleteSync();
      expect((await transly(['init', '-C', root])).exitCode, 0);
      expect(read(root, 'transly.yaml'), contains('dir: lib/l10n'));
      final report = await checkJson(root);
      expect(report['dirSource'], 'transly.yaml');
    });
  });

  group('shop_json_broken (Arabic base)', () {
    test('check finds exactly the planted problems', () async {
      final report = await checkJson(copyFixture('shop_json_broken'));
      expect(issueIds(report), {
        'missing de cart.cartItems.other',
        'missing en checkout.securityCode',
        'extra en promo.old',
        'invalid-json es 5',
        'placeholder fr home.homeGreeting',
        'unknown-key - auth.singIn',
        'wrong-args - home.homeGreeting',
        'wrong-args - common.ok',
        'unused ar auth.signIn',
        'unused ar profile.inviteReward',
        'hardcoded - 61',
        'hardcoded - 233',
      });
    });

    test('fix restores nested keys and leaves the invalid file alone', () async {
      final root = copyFixture('shop_json_broken');
      final esBefore = read(root, 'assets/translations/es.json');
      final r = await transly(['fix', '-C', root]);
      expect(r.exitCode, 65);
      expect(read(root, 'assets/translations/es.json'), esBefore);
      final en = jsonDecode(read(root, 'assets/translations/en.json')) as Map<String, dynamic>;
      expect((en['checkout'] as Map)['securityCode'], 'TODO: رمز الأمان');
      final de = jsonDecode(read(root, 'assets/translations/de.json')) as Map<String, dynamic>;
      expect(((de['cart'] as Map)['cartItems'] as Map).keys, ['zero', 'one', 'other']);
    });

    test('add en --base ar from scratch keeps the nesting', () async {
      final root = copyFixture('shop_json_broken');
      File(p.join(root, 'assets/translations/en.json')).deleteSync();
      final r = await transly(['add', 'en', '--base', 'ar', '-C', root, '--fill', 'empty']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final en = jsonDecode(read(root, 'assets/translations/en.json')) as Map<String, dynamic>;
      final ar = jsonDecode(read(root, 'assets/translations/ar.json')) as Map<String, dynamic>;
      expect(en.keys, ar.keys);
      expect((en['cart'] as Map)['cartItems'], {'zero': '', 'one': '', 'other': ''});
    });
  });

  group('live free translation (TRANSLY_LIVE=1)', () {
    final live = Platform.environment['TRANSLY_LIVE'] == '1';

    test('translate it (new) and en→ar for a slice, placeholders and plurals intact', () async {
      final root = copyFixture('shop_arb_broken');
      final r = await transly([
        'translate',
        'it',
        '-C',
        root,
        '-k',
        'cart*',
        '-k',
        'onlyLeft',
        '-k',
        'welcomeBack',
        '-k',
        'genderGreeting'
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final it = jsonDecode(read(root, 'lib/l10n/app_it.arb')) as Map<String, dynamic>;
      expect(it['welcomeBack'], contains('{name}'));
      expect(it['onlyLeft'], startsWith('{count, plural, =1{'));
      expect(it['genderGreeting'], startsWith('{gender, select, male{'));
      expect(it['@welcomeBack'], containsPair('x-translated', 'auto'));
      expect(it['settingsTitle'], 'TODO: Settings');
      final report = await checkJson(root);
      final placeholders =
          issueIds(report).where((i) => i.startsWith('placeholder it') || i.startsWith('icu-syntax it'));
      expect(placeholders, isEmpty);
      expect(issueIds(report, withInfo: true), contains('needs-review it welcomeBack'));
    }, skip: live ? false : 'set TRANSLY_LIVE=1', timeout: const Timeout(Duration(minutes: 3)));

    test('Arabic base → English for the JSON app', () async {
      final root = copyFixture('shop_json_broken');
      final r = await transly(['translate', 'en', '-C', root]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final en = jsonDecode(read(root, 'assets/translations/en.json')) as Map<String, dynamic>;
      expect((en['checkout'] as Map)['securityCode'], matches(RegExp('[A-Za-z]')));
      expect((en['checkout'] as Map)['securityCode'], isNot(contains('TODO')));
    }, skip: live ? false : 'set TRANSLY_LIVE=1', timeout: const Timeout(Duration(minutes: 3)));
  });
}
