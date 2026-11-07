// Using transly from Dart code instead of the command line.
//
// The command line is the usual way:
//
//   dart pub global activate transly
//   transly check            # in your Flutter project
//
// This script runs the same checks on the example shop app next to it and
// prints a one-line summary per locale.
import 'dart:io';

import 'package:transly/transly.dart';

Future<void> main(List<String> args) async {
  final root = args.isEmpty ? 'example/shop_arb' : args.first;
  final project = TranslyProject.load(root: root);
  final reports = checkFiles(
      project.base,
      project.targets,
      CheckOptions(
        displayPath: project.relative,
        ignoreUntranslated: project.config.ignoreUntranslated ?? const [],
      ));
  for (final r in reports) {
    final pct = (r.coverage * 100).toStringAsFixed(1);
    stdout.writeln('${r.locale.padRight(6)} $pct% translated, ${r.errors} errors, ${r.warnings} warnings');
  }

  final code = checkCode(project.base, collectDartSources(project.root, ['lib'], generatedDir: project.dir));
  stdout.writeln(
      '${code.filesScanned} Dart files, ${code.references.length} key references, ${code.issues.length} code findings');

  // Machine-translate two messages for free; placeholders and plurals survive.
  final result = await translateMessages(
    {
      'welcome': 'Welcome back, {name}!',
      'cart': '{count, plural, =0{Your cart is empty} =1{1 item} other{{count} items}}',
    },
    engines: enginesFor('auto'),
    from: 'en',
    to: 'ar',
  );
  result.translated.forEach((key, value) => stdout.writeln('$key → $value'));
}
