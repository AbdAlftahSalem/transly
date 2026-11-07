import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:transly/transly.dart';

import 'helpers.dart';

void main() {
  group('planFix (ARB)', () {
    late TranslyProject pr;
    setUp(() => pr = TranslyProject.load(root: copyFixture('arb_app')));

    test('adds missing keys in base order, keeps values and extras', () {
      final ar = pr.fileFor('ar')!;
      final plan = planFix(pr.base, ar);
      expect(plan.added, ['deleteAccount']);
      final out = jsonDecode(plan.after) as Map<String, dynamic>;
      expect(out.keys.where((k) => !k.startsWith('@')).toList(), [
        'appTitle',
        'welcome',
        'cartItems',
        'greeting',
        'settings',
        'signOut',
        'deleteAccount',
        'ok',
        'unusedBanner',
        'oldKey'
      ]);
      expect(out['@@locale'], 'ar');
      expect(out['deleteAccount'], 'TODO: Delete account');
      expect(out['appTitle'], 'المتجر');
      expect(out['oldKey'], 'قديم');
    });

    test('every existing value survives', () {
      final ar = pr.fileFor('ar')!;
      final out = jsonDecode(planFix(pr.base, ar).after) as Map<String, dynamic>;
      ar.entries.forEach((k, v) => expect(out[k], v, reason: k));
    });

    test('--remove-extra drops keys not in the base', () {
      final plan = planFix(pr.base, pr.fileFor('ar')!, removeExtra: true);
      expect(plan.removed, ['oldKey']);
      expect(jsonDecode(plan.after), isNot(contains('oldKey')));
    });

    test('fill modes', () {
      String fill(FillMode m) =>
          (jsonDecode(planFix(pr.base, pr.fileFor('ar')!, fill: m).after) as Map)['deleteAccount'] as String;
      expect(fill(FillMode.todo), 'TODO: Delete account');
      expect(fill(FillMode.empty), '');
      expect(fill(FillMode.base), 'Delete account');
    });

    test('2-space indent, unicode as-is, trailing newline', () {
      final after = planFix(pr.base, pr.fileFor('ar')!).after;
      expect(after, startsWith('{\n  "@@locale": "ar",\n'));
      expect(after, contains('"appTitle": "المتجر"'));
      expect(after, endsWith('}\n'));
    });

    test('refuses files with duplicate keys or invalid JSON', () {
      expect(() => planFix(pr.base, pr.fileFor('fr')!), throwsStateError);
      final broken = TranslationFile.parse('x/app_de.arb', '{"a": }');
      expect(() => planFix(pr.base, broken), throwsStateError);
    });

    test('a complete file is unchanged', () {
      final again = TranslationFile.parse(pr.base.path, pr.base.source);
      expect(planFix(pr.base, again).changed, isFalse);
    });

    test('metadata for new keys is copied from the base', () {
      final t = TranslationFile.parse('lib/l10n/app_de.arb', '{"@@locale": "de"}');
      final out = jsonDecode(planFix(pr.base, t).after) as Map<String, dynamic>;
      expect(out['@welcome'], {
        'placeholders': {
          'name': {'type': 'String'}
        }
      });
    });

    test('overrides and metadata extras (translate)', () {
      final plan = planFix(pr.base, pr.fileFor('ar')!, overrides: {
        'signOut': 'تسجيل الخروج'
      }, metadataExtra: {
        'signOut': {'x-translated': 'auto'}
      });
      final out = jsonDecode(plan.after) as Map<String, dynamic>;
      expect(out['signOut'], 'تسجيل الخروج');
      expect(out['@signOut'], {'x-translated': 'auto'});
      expect(plan.updated, ['signOut']);
    });
  });

  group('planFix (JSON)', () {
    test('nested structure is rebuilt in base order', () {
      final pr = TranslyProject.load(root: copyFixture('json_app'));
      final en = pr.fileFor('en')!;
      final plan = planFix(pr.base, en);
      final out = jsonDecode(plan.after) as Map<String, dynamic>;
      expect(out.keys.toList(), ['home', 'cart', 'profile', 'errors', 'about', 'brand', 'unused_tip', 'legacy']);
      expect(out['profile'], {'edit': 'TODO: تعديل الملف الشخصي'});
      expect((out['cart'] as Map)['items'], {'zero': 'Cart is empty', 'one': 'One product', 'other': '{} products'});
    });

    test('flat files stay flat', () {
      final base = TranslationFile.parse('a/en.json', '{"a.b": "AB", "c": "C"}');
      final de = TranslationFile.parse('a/de.json', '{"c": "Ce"}');
      expect(jsonDecode(planFix(base, de).after), {'a.b': 'TODO: AB', 'c': 'Ce'});
    });

    test('keeps a 4-space indent', () {
      final base = TranslationFile.parse('a/en.json', '{\n    "a": "A",\n    "b": "B"\n}\n');
      final de = TranslationFile.parse('a/de.json', '{\n    "a": "Ah"\n}\n');
      expect(planFix(base, de).after, '{\n    "a": "Ah",\n    "b": "TODO: B"\n}\n');
    });

    test('non-string values survive', () {
      final base = TranslationFile.parse('a/en.json', '{"list": ["a", "b"], "n": 3, "t": "T"}');
      final de = TranslationFile.parse('a/de.json', '{"t": "Te"}');
      expect(jsonDecode(planFix(base, de, fill: FillMode.base).after), {
        'list': ['a', 'b'],
        'n': 3,
        't': 'Te'
      });
    });
  });

  group('planNewLocale', () {
    test('ARB: name, @@locale, order, metadata', () {
      final pr = TranslyProject.load(root: copyFixture('arb_app'));
      final plan = planNewLocale(pr.base, 'de');
      expect(p.basename(plan.path), 'app_de.arb');
      expect(plan.created, isTrue);
      final out = jsonDecode(plan.after) as Map<String, dynamic>;
      expect(out.keys.first, '@@locale');
      expect(out['@@locale'], 'de');
      expect(out.keys.where((k) => !k.startsWith('@')), pr.base.entries.keys);
      expect(out['@cartItems'], isNotNull);
      expect(out['cartItems'], startsWith('TODO: {count, plural'));
    });

    test('JSON: nested like the base (Arabic base → English)', () {
      final pr = TranslyProject.load(root: copyFixture('json_app'));
      final plan = planNewLocale(pr.base, 'es', fill: FillMode.empty);
      expect(p.basename(plan.path), 'es.json');
      final out = jsonDecode(plan.after) as Map<String, dynamic>;
      expect((out['home'] as Map).keys, ['title', 'welcome']);
      expect((out['home'] as Map)['title'], '');
    });

    test('pathForLocale keeps the naming pattern', () {
      final base = TranslationFile.parse('/x/intl_en_US.arb', '{}');
      expect(p.basename(pathForLocale(base, 'pt_BR')), 'intl_pt_BR.arb');
    });

    test('write goes through a temp file', () {
      final dir = Directory.systemTemp.createTempSync('transly_w_').path;
      final plan = FilePlan(path: p.join(dir, 'sub', 'a.json'), before: '', after: '{}\n', created: true);
      plan.write();
      expect(File(plan.path).readAsStringSync(), '{}\n');
      expect(Directory(p.join(dir, 'sub')).listSync(), hasLength(1));
    });
  });

  test('unflatten handles a value where an object is needed', () {
    final out = unflatten([
      const MapEntry(['a'], 'A'),
      const MapEntry(['a', 'b'], 'AB'),
      const MapEntry(['c', 'd'], 'CD'),
    ]);
    expect(out, {
      'a': 'A',
      'a.b': 'AB',
      'c': {'d': 'CD'}
    });
  });

  group('unifiedDiff', () {
    test('shows added lines with context', () {
      final d = unifiedDiff('a\nb\nc\n', 'a\nb\nx\nc\n');
      expect(d, ['--- before', '+++ after', '@@ -1,3 +1,4 @@', ' a', ' b', '+x', ' c']);
    });

    test('no changes, no diff', () {
      expect(unifiedDiff('a\n', 'a\n'), isEmpty);
    });

    test('new file', () {
      expect(unifiedDiff('', 'a\n'), contains('+a'));
    });
  });
}
