// End to end: transly writes files into a real Flutter app, then Flutter's
// own tools (gen-l10n, analyze, test) must accept them. Needs `flutter` on
// the PATH; skipped otherwise.
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String? flutterBin() {
  final r = Process.runSync(Platform.isWindows ? 'where' : 'which', ['flutter']);
  return r.exitCode == 0 ? (r.stdout as String).split('\n').first.trim() : null;
}

void copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final name = p.basename(e.path);
    if (name == '.dart_tool' || name == 'build') continue;
    final t = p.join(to.path, name);
    if (e is Directory) {
      copyDir(e, Directory(t));
    } else if (e is File) {
      e.copySync(t);
    }
  }
}

void main() {
  final flutter = flutterBin();
  final live = Platform.environment['TRANSLY_LIVE'] == '1';

  test('add + translate output is accepted by flutter gen-l10n, analyze and test', () async {
    final pkg = Directory.current.path;
    final app = Directory.systemTemp.createTempSync('transly_e2e_').path;
    copyDir(Directory(p.join(pkg, 'example', 'shop_arb')), Directory(app));
    // Point the dev dependency at this checkout from the temp folder.
    final pubspec = File(p.join(app, 'pubspec.yaml'));
    pubspec.writeAsStringSync(
        pubspec.readAsStringSync().replaceFirst('path: ../..', 'path: ${pkg.replaceAll(r'\', '/')}'));

    Future<ProcessResult> run(String exe, List<String> args) =>
        Process.run(exe, args, workingDirectory: app, runInShell: Platform.isWindows);

    var r = await run(flutter!, ['pub', 'get']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    // Italian: machine-translated when live, else "TODO: <English>" values.
    r = await run('dart', ['run', 'transly', 'add', 'it', if (live) '--translate']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    // Break French, then let transly repair it.
    final fr = File(p.join(app, 'lib', 'l10n', 'app_fr.arb'));
    fr.writeAsStringSync(fr.readAsStringSync().replaceFirst(RegExp(r'\n  "checkoutTitle": "[^"]*",'), ''));
    r = await run('dart', ['run', 'transly', 'check', '--ci']);
    expect(r.exitCode, 1);
    r = await run('dart', ['run', 'transly', 'fix']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    r = await run('dart', ['run', 'transly', 'check', '--ci']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');

    r = await run(flutter, ['gen-l10n']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(File(p.join(app, 'lib', 'l10n', 'app_localizations_it.dart')).existsSync(), isTrue);
    r = await run(flutter, ['analyze']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    r = await run(flutter, ['test']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }, skip: flutter == null ? 'flutter is not on the PATH' : false, timeout: const Timeout(Duration(minutes: 10)));
}
