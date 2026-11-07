import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:transly/transly.dart';

import 'helpers.dart';

void main() {
  test('l10n.yaml gives the folder and the template as base', () {
    final pr = TranslyProject.load(root: copyFixture('arb_app'));
    expect(pr.dirSource, 'l10n.yaml');
    expect(pr.relativeDir, 'lib/l10n');
    expect(pr.base.locale, 'en');
    expect(pr.baseSource, 'l10n.yaml template');
    expect(pr.format, TranslationFormat.arb);
    expect(pr.files.map((f) => f.locale), ['en', 'ar', 'fr']);
    expect(pr.l10n!.outputClass, 'AppLocalizations');
  });

  test('transly.yaml sets folder and base', () {
    final pr = TranslyProject.load(root: copyFixture('json_app'));
    expect(pr.dirSource, 'transly.yaml');
    expect(pr.base.locale, 'ar');
    expect(pr.format, TranslationFormat.json);
    expect(pr.config.ignoreUntranslated, ['brand']);
  });

  test('command line wins', () {
    final pr = TranslyProject.load(root: copyFixture('json_app'), cli: const TranslyConfig(base: 'en'));
    expect(pr.base.locale, 'en');
    expect(pr.baseSource, '--base');
  });

  test('a common folder is found when nothing is configured', () {
    final root = Directory.systemTemp.createTempSync('transly_find_').path;
    write(root, 'assets/lang/en.json', '{"a": "A"}');
    write(root, 'assets/lang/es.json', '{"a": "A es"}');
    final pr = TranslyProject.load(root: root);
    expect(pr.dirSource, 'found');
    expect(pr.relativeDir, 'assets/lang');
    expect(pr.base.locale, 'en');
  });

  test('base falls back to the first file without en', () {
    final root = Directory.systemTemp.createTempSync('transly_find_').path;
    write(root, 'assets/i18n/fr.json', '{"a": "A"}');
    write(root, 'assets/i18n/ar.json', '{"a": "B"}');
    expect(TranslyProject.load(root: root).base.locale, 'ar');
  });

  test('files without a locale in the name are skipped', () {
    final root = Directory.systemTemp.createTempSync('transly_find_').path;
    write(root, 'assets/translations/en.json', '{"a": "A"}');
    write(root, 'assets/translations/config.json', '{"x": 1}');
    final pr = TranslyProject.load(root: root);
    expect(pr.files, hasLength(1));
    expect(pr.skipped, ['config.json']);
  });

  test('clear errors', () {
    final empty = Directory.systemTemp.createTempSync('transly_none_').path;
    expect(
        () => TranslyProject.load(root: empty), throwsA(isA<TranslyException>().having((e) => e.exitCode, 'code', 66)));
    expect(
      () => TranslyProject.load(root: copyFixture('arb_app'), cli: const TranslyConfig(base: 'de')),
      throwsA(isA<TranslyException>().having((e) => e.message, 'message', contains('found: ar, en, fr'))),
    );
    expect(
      () => TranslyProject.load(root: copyFixture('arb_app'), cli: const TranslyConfig(dir: 'nope')),
      throwsA(isA<TranslyException>()),
    );
  });

  test('transly.yaml parsing and round trip', () {
    final c = TranslyConfig.fromYaml('dir: assets/lang\nbase: ar\nformat: json\nignore_keys: [a, "b_*"]\nsources: lib');
    expect(c.dir, 'assets/lang');
    expect(c.base, 'ar');
    expect(c.format, TranslationFormat.json);
    expect(c.ignoreKeys, ['a', 'b_*']);
    expect(c.sources, ['lib']);
    final again = TranslyConfig.fromYaml(c.toYaml());
    expect(again.dir, c.dir);
    expect(again.base, c.base);
    expect(again.format, c.format);
    expect(() => TranslyConfig.fromYaml('format: xml'), throwsA(isA<TranslyException>()));
    expect(() => TranslyConfig.fromYaml('- a'), throwsA(isA<TranslyException>()));
  });
}
