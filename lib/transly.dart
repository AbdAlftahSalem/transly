/// transly: find and fix translation problems in Flutter and Dart projects.
///
/// The `transly` command line tool is the main entry point
/// (`dart run transly check`). This library exposes the same building blocks
/// for scripts and tests:
///
/// * [TranslyProject.load] finds the translations folder and loads the files.
/// * [checkFiles] compares every locale with the base locale.
/// * [checkCode] checks Dart code: unknown keys, wrong arguments, unused keys,
///   hardcoded strings.
/// * [planFix] and [planNewLocale] create or complete files without losing data.
/// * [translateMessages] machine-translates messages for free while keeping
///   placeholders and ICU plurals intact.
library;

export 'src/checker.dart';
export 'src/cli.dart' show runTransly;
export 'src/code_check.dart';
export 'src/config.dart';
export 'src/dart_scanner.dart';
export 'src/icu.dart';
export 'src/issue.dart';
export 'src/json_reader.dart';
export 'src/locale_name.dart';
export 'src/report.dart' show Ansi, githubAnnotations;
export 'src/review.dart';
export 'src/translate.dart';
export 'src/translation_file.dart';
export 'src/version.dart';
export 'src/writer.dart';
