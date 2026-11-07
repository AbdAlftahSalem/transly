/// The command-line interface.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'checker.dart';
import 'code_check.dart';
import 'config.dart';
import 'issue.dart';
import 'locale_name.dart';
import 'report.dart';
import 'review.dart';
import 'translate.dart';
import 'translation_file.dart';
import 'version.dart';
import 'writer.dart';

/// Runs the CLI with [args] and returns the exit code.
///
/// [out] and [err] default to stdout and stderr; [engines] replaces the
/// free translation engines (tests use a fake one).
Future<int> runTransly(
  List<String> args, {
  StringSink? out,
  StringSink? err,
  bool? color,
  Map<String, String>? environment,
  List<TranslationEngine>? engines,
}) async {
  final env = environment ?? Platform.environment;
  final o = out ?? stdout;
  final e = err ?? stderr;
  final forced = env['FORCE_COLOR'];
  final autoColor = color ??
      (env.containsKey('NO_COLOR')
          ? false
          : (forced != null && forced != '0' && forced != 'false') ||
              (out == null && stdout.hasTerminal && stdout.supportsAnsiEscapes));
  final runner = _Runner(_Env(o, e, autoColor, env, engines));
  var argv = List<String>.from(args);
  if (!_hasCommand(argv, runner.commands.keys.toSet()) &&
      !argv.contains('-h') &&
      !argv.contains('--help') &&
      !argv.contains('--version')) {
    argv = ['check', ...argv];
  }
  try {
    if (argv.contains('--version') && !argv.contains('help')) {
      o.writeln('$toolName $toolVersion');
      return 0;
    }
    final code = await runner.run(argv);
    return code ?? 0;
  } on UsageException catch (x) {
    e.writeln(x.message);
    e.writeln();
    e.writeln(x.usage);
    return 64;
  } on TranslyException catch (x) {
    e.writeln('${Ansi(autoColor).red('error:')} ${x.message}');
    return x.exitCode;
  } on StateError catch (x) {
    e.writeln('${Ansi(autoColor).red('error:')} ${x.message}');
    return 65;
  }
}

/// Whether [argv] names a command (the first word that is not an option or
/// an option's value).
bool _hasCommand(List<String> argv, Set<String> commands) {
  const withValue = {'-C', '--root', '-d', '--dir', '-b', '--base', '--format'};
  for (var i = 0; i < argv.length; i++) {
    final x = argv[i];
    if (withValue.contains(x)) {
      i++;
      continue;
    }
    if (x.startsWith('-')) continue;
    return commands.contains(x);
  }
  return false;
}

class _Env {
  _Env(this.out, this.err, this.color, this.environment, this.engines);
  final StringSink out;
  final StringSink err;
  final bool color;
  final Map<String, String> environment;
  final List<TranslationEngine>? engines;
}

class _Runner extends CommandRunner<int> {
  _Runner(this.env)
      : super(
            toolName,
            'Find and fix translation problems in Flutter and Dart projects (.arb and .json).\n'
            'Run without a command to check the project in the current folder.') {
    argParser
      ..addOption('root', abbr: 'C', help: 'The project folder.', defaultsTo: '.')
      ..addOption('dir',
          abbr: 'd', help: 'The translations folder (default: from l10n.yaml, $configFileName, or found).')
      ..addOption('base', abbr: 'b', help: 'The base locale (default: l10n.yaml template, $configFileName, or en).')
      ..addOption('format', allowed: ['auto', 'arb', 'json'], defaultsTo: 'auto', help: 'The file format.')
      ..addFlag('json', negatable: false, help: 'Print a JSON report instead of text.')
      ..addFlag('ci',
          negatable: false, help: 'Exit with code 1 when problems are found; add GitHub annotations on GitHub Actions.')
      ..addFlag('color', defaultsTo: null, help: 'Color the output (default: when writing to a terminal).')
      ..addFlag('all', negatable: false, help: 'List every finding (default: up to 25 per section).')
      ..addFlag('version', negatable: false, help: 'Print the version.');
    addCommand(_CheckCommand(env));
    addCommand(_FixCommand(env));
    addCommand(_AddCommand(env));
    addCommand(_TranslateCommand(env));
    addCommand(_UnusedCommand(env));
    addCommand(_HardcodedCommand(env));
    addCommand(_InitCommand(env));
  }

  final _Env env;

  @override
  String get invocation => '$toolName [command] [options]';
}

abstract class _Base extends Command<int> {
  _Base(this.env);

  final _Env env;

  StringSink get out => env.out;

  ArgResults get g => globalResults!;

  ArgResults get a => argResults!;

  bool get json => g['json'] as bool;

  bool get ci => g['ci'] as bool;

  Ansi get ansi => Ansi(!json && ((g['color'] as bool?) ?? env.color));

  int get limit => (g['all'] as bool) ? 1 << 30 : 25;

  TranslyConfig cliConfig({List<String>? ignoreKeys}) => TranslyConfig(
        dir: g['dir'] as String?,
        base: g['base'] as String?,
        format: TranslationFormat.tryParse(g['format'] as String?),
        ignoreKeys: ignoreKeys,
      );

  TranslyProject loadProject({List<String>? ignoreKeys}) =>
      TranslyProject.load(root: g['root'] as String, cli: cliConfig(ignoreKeys: ignoreKeys));

  String header(TranslyProject pr, {int? dartFiles}) {
    final base = pr.base;
    final parts = [
      '${ansi.bold(toolName)} ${ansi.gray(toolVersion)}',
      '${ansi.cyan(pr.relativeDir)} ${ansi.gray('(${pr.dirSource})')}',
      'base ${ansi.bold(base.locale)} ${ansi.gray('(${pr.baseSource})')}',
      '${base.entries.length} keys',
      '${pr.files.length} locales',
      if (dartFiles != null) '$dartFiles Dart files',
    ];
    return parts.join(ansi.gray('  ·  '));
  }

  List<DartSource> sources(TranslyProject pr) => collectDartSources(
        pr.root,
        pr.config.sources ?? const ['lib'],
        ignoreGlobs: pr.config.ignoreFiles ?? const [],
        generatedDir: pr.dir,
      );

  CodeCheckOptions codeOptions(TranslyProject pr, {bool unused = true, bool unknown = true, bool hardcoded = true}) =>
      CodeCheckOptions(
        unused: unused,
        unknown: unknown,
        hardcoded: hardcoded,
        accessors: pr.config.accessors ?? const [],
        outputClass: pr.l10n?.outputClass ?? 'AppLocalizations',
        ignoreKeys: pr.config.ignoreKeys ?? const [],
      );

  void section(String title, List<Issue> issues, {bool showFile = false}) {
    if (issues.isEmpty) return;
    out.writeln();
    out.writeln(title);
    final shown = issues.take(limit).toList();
    out.writeln(table(issueRows(shown, ansi, showFile: showFile)));
    if (issues.length > shown.length) {
      out.writeln(ansi.gray('  … and ${issues.length - shown.length} more (use --all)'));
    }
  }

  void annotate(Iterable<Issue> issues) {
    if (ci && env.environment['GITHUB_ACTIONS'] == 'true') {
      githubAnnotations(issues).forEach(out.writeln);
    }
  }

  Map<String, Object?> projectJson(TranslyProject pr) => {
        'tool': toolName,
        'version': toolVersion,
        'root': pr.root,
        'dir': pr.relativeDir,
        'dirSource': pr.dirSource,
        'format': pr.format.name,
        'base': pr.base.locale,
        'baseFile': pr.relative(pr.base.path),
      };
}

class _CheckCommand extends _Base {
  _CheckCommand(super.env) {
    argParser
      ..addFlag('code',
          defaultsTo: true,
          help: 'Also check the Dart code: unknown keys, wrong arguments, unused keys, hardcoded strings.')
      ..addFlag('unused', defaultsTo: true, help: 'Report base keys no Dart file references (with --code).')
      ..addFlag('hardcoded', defaultsTo: true, help: 'Report user-facing strings that are not localized (with --code).')
      ..addFlag('identical', defaultsTo: true, help: 'Report values that are the same as the base text.')
      ..addFlag('review', negatable: false, help: 'List every machine translation awaiting review (default: a count).')
      ..addMultiOption('ignore-key', help: 'Skip a key (wildcards * and ? work). Repeatable.')
      ..addOption('fail-on',
          allowed: ['error', 'warning', 'never'], defaultsTo: 'error', help: 'With --ci: which findings fail the run.');
  }

  @override
  String get name => 'check';

  @override
  String get description => 'Compare every locale with the base and check the code (the default command).';

  @override
  Future<int> run() async {
    final pr =
        loadProject(ignoreKeys: (a['ignore-key'] as List<String>).isEmpty ? null : a['ignore-key'] as List<String>);
    final review = ReviewLog.read(pr.root);
    final reports = checkFiles(
      pr.base,
      pr.targets,
      CheckOptions(
        checkIdentical: a['identical'] as bool,
        ignoreKeys: pr.config.ignoreKeys ?? const [],
        ignoreUntranslated: pr.config.ignoreUntranslated ?? const [],
        displayPath: pr.relative,
        machineTranslated: review.machineText,
      ),
    );
    CodeReport? code;
    final srcs = a['code'] as bool ? sources(pr) : <DartSource>[];
    if (a['code'] as bool) {
      code = checkCode(pr.base, srcs, codeOptions(pr, unused: a['unused'] as bool, hardcoded: a['hardcoded'] as bool));
    }
    final all = [for (final r in reports) ...r.issues, ...?code?.issues];
    final c = countSeverities(all);
    final failOn = a['fail-on'] as String;
    final failed = ci && ((failOn == 'error' && c.errors > 0) || (failOn == 'warning' && (c.errors + c.warnings) > 0));

    if (json) {
      out.writeln(prettyJson({
        ...projectJson(pr),
        'dartFiles': code?.filesScanned,
        'locales': [
          for (final r in reports)
            {
              'locale': r.locale,
              'file': pr.relative(r.file.path),
              'base': r.isBase,
              'keys': r.file.entries.length,
              'translated': r.translated,
              'coverage': double.parse(r.coverage.toStringAsFixed(4)),
              'errors': r.errors,
              'warnings': r.warnings,
              'counts': {
                for (final k in IssueKind.values)
                  if (r.count(k) > 0) k.id: r.count(k)
              },
            },
        ],
        'issues': [for (final i in all) i.toJson()],
        'summary': {'errors': c.errors, 'warnings': c.warnings, 'info': c.infos, 'failed': failed},
      }));
      return failed ? 1 : 0;
    }

    annotate(all);
    out.writeln(header(pr, dartFiles: code?.filesScanned));
    if (code != null && code.filesScanned == 0) {
      out.writeln(
          ansi.gray('No Dart files in ${(pr.config.sources ?? const ['lib']).join(', ')}: code checks skipped.'));
    }
    out.writeln();
    out.writeln(localeTable(reports, ansi));
    final listReview = a['review'] as bool;
    for (final r in reports) {
      final shown = listReview ? r.issues : r.issues.where((i) => i.kind != IssueKind.needsReview).toList();
      section('${ansi.bold(r.locale)}  ${ansi.gray(pr.relative(r.file.path))}', shown);
    }
    if (code != null) {
      final unknown =
          code.issues.where((i) => i.kind == IssueKind.unknownKey || i.kind == IssueKind.wrongArguments).toList();
      final unused = code.issues.where((i) => i.kind == IssueKind.unusedKey).toList();
      final hard = code.issues.where((i) => i.kind == IssueKind.hardcodedString).toList();
      section('${ansi.bold('code')}  ${ansi.gray('keys used in Dart that are wrong')}', unknown, showFile: true);
      section('${ansi.bold('unused')}  ${ansi.gray('base keys no Dart file references')}', unused);
      section('${ansi.bold('hardcoded')}  ${ansi.gray('strings shown to users that are not localized')}', hard,
          showFile: true);
    }
    out.writeln();
    out.writeln(summaryLine(all, ansi));
    if (c.infos > 0 && !listReview) {
      out.writeln(ansi.gray('${c.infos} machine translations are waiting for a person to check them '
          '("$toolName check --review" lists them).'));
    }
    final missing = reports.fold<int>(0, (s, r) => s + r.count(IssueKind.missingKey));
    if (missing > 0) {
      out.writeln(ansi.gray(
          'Run "$toolName fix" to add the $missing missing ${missing == 1 ? 'key' : 'keys'}, or "$toolName translate" to machine-translate them.'));
    }
    return failed ? 1 : 0;
  }
}

class _FixCommand extends _Base {
  _FixCommand(super.env) {
    argParser
      ..addOption('fill',
          allowed: ['todo', 'empty', 'base'],
          defaultsTo: 'todo',
          help: 'Value for added keys: "TODO: <base text>", empty, or the base text.')
      ..addFlag('remove-extra', negatable: false, help: 'Delete keys that are not in the base.')
      ..addFlag('dry-run', negatable: false, help: 'Show the changes as a diff without writing.')
      ..addMultiOption('locale', abbr: 'l', help: 'Only fix these locales.');
  }

  @override
  String get name => 'fix';

  @override
  String get description => 'Add missing keys to every locale in base order, keeping every existing value.';

  @override
  Future<int> run() async {
    final pr = loadProject();
    final only = (a['locale'] as List<String>).map(normalizeLocale).toSet();
    final dry = a['dry-run'] as bool;
    final fill = FillMode.parse(a['fill'] as String);
    final results = <Map<String, Object?>>[];
    var problems = 0;
    if (!json) out.writeln(header(pr));
    if (!pr.base.isValid) {
      throw TranslyException('the base file ${pr.base.fileName} is not valid JSON: ${pr.base.error}', exitCode: 65);
    }
    for (final t in pr.targets) {
      if (only.isNotEmpty && !only.contains(normalizeLocale(t.locale))) continue;
      FilePlan plan;
      try {
        plan = planFix(pr.base, t, fill: fill, removeExtra: a['remove-extra'] as bool);
      } on StateError catch (x) {
        problems++;
        results.add({'locale': t.locale, 'file': pr.relative(t.path), 'skipped': x.message});
        if (!json) out.writeln('  ${ansi.red('✖')} ${ansi.bold(t.locale)}  skipped: ${x.message}');
        continue;
      }
      results.add({
        'locale': t.locale,
        'file': pr.relative(t.path),
        'changed': plan.changed,
        'added': plan.added,
        'removed': plan.removed,
        'reordered': plan.reorderedOnly,
      });
      if (!json) {
        final what = !plan.changed
            ? ansi.gray('already complete')
            : [
                if (plan.added.isNotEmpty) ansi.green('+${plan.added.length} added'),
                if (plan.removed.isNotEmpty) ansi.red('-${plan.removed.length} removed'),
                if (plan.reorderedOnly) ansi.yellow('reordered to match the base'),
              ].join('  ');
        out.writeln(
            '  ${plan.changed ? ansi.green('✔') : ansi.gray('·')} ${pad(ansi.bold(t.locale), 8)} ${pad(ansi.gray(t.fileName), 16)} $what');
        if (dry && plan.changed) {
          for (final line
              in unifiedDiff(plan.before, plan.after, fromName: pr.relative(t.path), toName: pr.relative(t.path))) {
            out.writeln(line.startsWith('+') && !line.startsWith('+++')
                ? ansi.green(line)
                : line.startsWith('-') && !line.startsWith('---')
                    ? ansi.red(line)
                    : ansi.gray(line));
          }
        }
      }
      if (!dry && plan.changed) plan.write();
    }
    if (json) {
      out.writeln(prettyJson({...projectJson(pr), 'dryRun': dry, 'files': results}));
    } else if (dry) {
      out.writeln(ansi.gray('Dry run: nothing was written.'));
    }
    return problems > 0 ? 65 : 0;
  }
}

class _AddCommand extends _Base {
  _AddCommand(super.env) {
    argParser
      ..addOption('fill',
          allowed: ['todo', 'empty', 'base'],
          defaultsTo: 'todo',
          help: 'Values: "TODO: <base text>", empty, or the base text.')
      ..addFlag('copy-base', negatable: false, help: 'Same as --fill base.')
      ..addFlag('translate', negatable: false, help: 'Machine-translate the values (free, no key).')
      ..addOption('engine',
          allowed: ['auto', 'google', 'mymemory'], defaultsTo: 'auto', help: 'With --translate: the free engine.')
      ..addOption('email', help: 'With --translate: an email for MyMemory (raises its free daily limit).')
      ..addFlag('force', negatable: false, help: 'Overwrite the file if it already exists.')
      ..addFlag('dry-run', negatable: false, help: 'Show the file without writing it.');
  }

  @override
  String get name => 'add';

  @override
  String get description => 'Create a new locale file with every base key, in base order, metadata included.';

  @override
  String get invocation => '$toolName add <locale> [--base <locale>] [options]';

  @override
  Future<int> run() async {
    if (a.rest.length != 1) usageException('Give exactly one locale, e.g. "$toolName add fr".');
    final locale = a.rest.single;
    if (localeFromFileName(locale)?.locale != locale) {
      usageException('"$locale" does not look like a locale (en, ar, pt_BR, zh_Hant).');
    }
    final pr = loadProject();
    if (!pr.base.isValid) {
      throw TranslyException('the base file ${pr.base.fileName} is not valid JSON: ${pr.base.error}', exitCode: 65);
    }
    final existing = pr.fileFor(locale);
    if (existing != null && !(a['force'] as bool)) {
      throw TranslyException(
          '${pr.relative(existing.path)} already exists. Use "$toolName fix" or "$toolName translate $locale" to fill it, or --force to replace it.');
    }
    final fill = a['copy-base'] as bool ? FillMode.base : FillMode.parse(a['fill'] as String);
    var overrides = <String, String>{};
    var metaExtra = <String, Map<String, Object?>>{};
    TranslationResult? tr;
    if (a['translate'] as bool) {
      final messages = {
        for (final e in pr.base.entries.entries)
          if (e.value is String &&
              (e.value as String).trim().isNotEmpty &&
              !KeyMatcher(pr.config.ignoreKeys ?? const []).matches(e.key))
            e.key: e.value as String,
      };
      tr = await _translate(this, pr, messages, locale, a['engine'] as String, a['email'] as String?);
      overrides = tr.translated;
      metaExtra = {
        for (final k in tr.translated.keys) k: {'x-translated': 'auto'}
      };
    }
    final plan = planNewLocale(pr.base, locale, fill: fill, overrides: overrides, metadataExtra: metaExtra);
    final rel = pr.relative(plan.path);
    if (a['dry-run'] as bool) {
      if (json) {
        out.writeln(prettyJson({...projectJson(pr), 'dryRun': true, 'file': rel, 'content': plan.after}));
      } else {
        out.writeln(ansi.gray('Dry run: $rel would be:'));
        out.write(plan.after);
      }
      return 0;
    }
    plan.write();
    if (tr != null) _logReview(pr, locale, tr);
    if (json) {
      out.writeln(prettyJson({
        ...projectJson(pr),
        'created': rel,
        'keys': pr.base.entries.length,
        'translated': tr?.translated.length,
        'failed': tr?.failed
      }));
    } else {
      out.writeln(
          '${ansi.green('✔')} Created ${ansi.bold(rel)} with ${pr.base.entries.length} keys from ${ansi.bold(pr.base.locale)}'
          '${tr == null ? ' (values: ${fill.name})' : ', ${tr.translated.length} machine-translated'}.');
      if (tr != null && tr.failed.isNotEmpty) {
        out.writeln(ansi.yellow(
            '▲ ${tr.failed.length} could not be translated and got "${fill.name}" values: ${tr.failed.keys.take(8).join(', ')}${tr.failed.length > 8 ? ', …' : ''}'));
      }
      if (pr.format == TranslationFormat.arb) {
        out.writeln(ansi.gray('Flutter picks it up on the next "flutter gen-l10n" (or build).'));
      } else {
        out.writeln(ansi.gray('Add Locale(\'${languageOf(locale)}\') to supportedLocales in your app.'));
      }
    }
    return 0;
  }
}

class _TranslateCommand extends _Base {
  _TranslateCommand(super.env) {
    argParser
      ..addFlag('overwrite',
          negatable: false, help: 'Translate every key again, not only missing, empty and TODO ones.')
      ..addFlag('dry-run', negatable: false, help: 'Show the translations without writing.')
      ..addOption('engine',
          allowed: ['auto', 'google', 'mymemory'],
          defaultsTo: 'auto',
          help: 'The free engine (auto = Google, then MyMemory for the rest).')
      ..addOption('email', help: 'An email for MyMemory (raises its free daily limit).')
      ..addMultiOption('keys', abbr: 'k', help: 'Only these keys (wildcards * and ? work).')
      ..addOption('fill',
          allowed: ['todo', 'empty', 'base'], defaultsTo: 'todo', help: 'Value for keys that could not be translated.');
  }

  @override
  String get name => 'translate';

  @override
  String get description =>
      'Machine-translate missing, empty and TODO values for free (no API key), keeping placeholders and ICU plurals intact.';

  @override
  String get invocation => '$toolName translate [<locale> ...] [--base <locale>] [options]';

  @override
  Future<int> run() async {
    final pr = loadProject();
    if (!pr.base.isValid) {
      throw TranslyException('the base file ${pr.base.fileName} is not valid JSON: ${pr.base.error}', exitCode: 65);
    }
    final locales = a.rest.isEmpty ? pr.targets.map((t) => t.locale).toList() : a.rest;
    if (locales.isEmpty) usageException('No locale to translate into. Example: "$toolName translate ar --base en".');
    final overwrite = a['overwrite'] as bool;
    final dry = a['dry-run'] as bool;
    final ignore = KeyMatcher(pr.config.ignoreKeys ?? const []);
    final only = (a['keys'] as List<String>).isEmpty ? null : KeyMatcher(a['keys'] as List<String>);
    final fill = FillMode.parse(a['fill'] as String);
    final summary = <Map<String, Object?>>[];
    if (!json) out.writeln(header(pr));
    for (final locale in locales) {
      if (normalizeLocale(locale) == normalizeLocale(pr.base.locale)) usageException('"$locale" is the base locale.');
      final target = pr.fileFor(locale);
      final messages = <String, String>{};
      for (final e in pr.base.entries.entries) {
        final v = e.value;
        if (v is! String || v.trim().isEmpty || ignore.matches(e.key)) continue;
        if (only != null && !only.matches(e.key)) continue;
        final current = target?.stringValue(e.key);
        final needs = overwrite ||
            target == null ||
            !target.entries.containsKey(e.key) ||
            current == null ||
            current.trim().isEmpty ||
            isTodo(current);
        if (needs) messages[e.key] = v;
      }
      if (messages.isEmpty) {
        if (!json) out.writeln('  ${ansi.gray('·')} ${ansi.bold(locale)}  nothing to translate');
        summary.add({'locale': locale, 'translated': 0, 'failed': <String, String>{}});
        continue;
      }
      final tr = await _translate(this, pr, messages, locale, a['engine'] as String, a['email'] as String?);
      final metaExtra = {
        for (final k in tr.translated.keys) k: <String, Object?>{'x-translated': 'auto'}
      };
      final plan = target == null
          ? planNewLocale(pr.base, locale, fill: fill, overrides: tr.translated, metadataExtra: metaExtra)
          : planFix(pr.base, target, fill: fill, overrides: tr.translated, metadataExtra: metaExtra);
      summary.add({
        'locale': locale,
        'file': pr.relative(plan.path),
        'created': plan.created,
        'translated': tr.translated.length,
        'failed': tr.failed,
        'engines': tr.engineByKey,
        if (dry) 'translations': tr.translated,
      });
      if (!json) {
        if (dry) {
          final rows = [
            for (final e in tr.translated.entries.take(limit))
              [ansi.bold(e.key), ansi.gray(_clip(messages[e.key]!)), '→', _clip(e.value)],
          ];
          out.writeln(table(rows));
          if (tr.translated.length > limit) {
            out.writeln(ansi.gray('  … and ${tr.translated.length - limit} more (use --all)'));
          }
        }
        out.writeln('  ${ansi.green('✔')} ${ansi.bold(locale)}  ${tr.translated.length} translated'
            '${tr.failed.isEmpty ? '' : ansi.yellow(', ${tr.failed.length} failed (${fill.name} kept)')}'
            '  ${ansi.gray(pr.relative(plan.path))}${plan.created ? ansi.gray(' (new)') : ''}');
        for (final f in tr.failed.entries.take(5)) {
          out.writeln(ansi.yellow('    ▲ ${f.key}: ${f.value}'));
        }
      }
      if (!dry) {
        plan.write();
        _logReview(pr, locale, tr);
      }
    }
    if (json) {
      out.writeln(prettyJson({...projectJson(pr), 'dryRun': dry, 'locales': summary}));
    } else if (dry) {
      out.writeln(ansi.gray('Dry run: nothing was written.'));
    } else {
      out.writeln(ansi.gray(
          'Machine translations are marked for review in $reviewFileName${pr.format == TranslationFormat.arb ? ' and with "x-translated": "auto" in the ARB metadata' : ''}.'));
      out.writeln(ansi.gray('"$toolName check" lists them until a person edits them.'));
    }
    final failed = summary.fold<int>(0, (s, m) => s + (m['failed'] as Map).length);
    return ci && failed > 0 ? 1 : 0;
  }
}

String _clip(String s, [int max = 44]) {
  final one = s.replaceAll('\n', r'\n');
  return one.runes.length <= max ? one : '${String.fromCharCodes(one.runes.take(max - 1))}…';
}

Future<TranslationResult> _translate(
    _Base cmd, TranslyProject pr, Map<String, String> messages, String locale, String engine, String? email) async {
  final engines = cmd.env.engines ?? enginesFor(engine, email: email);
  if (!cmd.json) {
    cmd.out.writeln(cmd.ansi.gray(
        '  Translating ${messages.length} ${messages.length == 1 ? 'text' : 'texts'} ${pr.base.locale} → $locale (free: ${engines.map((x) => x.name).join(', then ')}) …'));
  }
  return translateMessages(messages, engines: engines, from: pr.base.locale, to: locale);
}

void _logReview(TranslyProject pr, String locale, TranslationResult tr) {
  if (tr.translated.isEmpty) return;
  final log = ReviewLog.read(pr.root);
  final base = pr.base;
  for (final e in tr.translated.entries) {
    log.add(locale, e.key, ReviewEntry(base.stringValue(e.key) ?? '', e.value, tr.engineByKey[e.key] ?? ''));
  }
  log.write();
}

class _UnusedCommand extends _Base {
  _UnusedCommand(super.env);

  @override
  String get name => 'unused';

  @override
  String get description => 'List base keys that no Dart file references (heuristic; see README).';

  @override
  Future<int> run() async {
    final pr = loadProject();
    final srcs = sources(pr);
    final report = checkCode(pr.base, srcs, codeOptions(pr, unknown: false, hardcoded: false));
    final issues = report.issues;
    if (json) {
      out.writeln(prettyJson({
        ...projectJson(pr),
        'dartFiles': srcs.length,
        'unused': [for (final i in issues) i.key]
      }));
    } else {
      annotate(issues);
      out.writeln(header(pr, dartFiles: srcs.length));
      section('${ansi.bold('unused')}  ${ansi.gray('base keys no Dart file references')}', issues);
      out.writeln();
      out.writeln(issues.isEmpty
          ? '${ansi.green('✔')} Every key is referenced.'
          : ansi.yellow('▲ ${issues.length} unused of ${pr.base.entries.length} keys'));
    }
    return ci && issues.isNotEmpty ? 1 : 0;
  }
}

class _HardcodedCommand extends _Base {
  _HardcodedCommand(super.env);

  @override
  String get name => 'hardcoded';

  @override
  String get description =>
      'List user-facing strings in widgets that are not localized (heuristic; silence with // $ignoreMarker).';

  @override
  Future<int> run() async {
    final root = p.normalize(p.absolute(g['root'] as String));
    TranslyProject? pr;
    try {
      pr = loadProject();
    } on TranslyException {
      pr = null; // A project with no translations yet can still be scanned.
    }
    final srcs = pr != null ? sources(pr) : collectDartSources(root, const ['lib']);
    final keys = pr?.base.entries.keys.toSet() ?? const <String>{};
    final issues = [for (final s in srcs) ...findHardcodedStrings(s, knownKeys: keys)];
    if (json) {
      out.writeln(prettyJson({
        'tool': toolName,
        'version': toolVersion,
        'dartFiles': srcs.length,
        'issues': [for (final i in issues) i.toJson()]
      }));
    } else {
      annotate(issues);
      out.writeln('${ansi.bold(toolName)} ${ansi.gray(toolVersion)}${ansi.gray('  ·  ')}${srcs.length} Dart files');
      section('${ansi.bold('hardcoded')}  ${ansi.gray('strings shown to users that are not localized')}', issues,
          showFile: true);
      out.writeln();
      out.writeln(issues.isEmpty
          ? '${ansi.green('✔')} No hardcoded user-facing strings found.'
          : ansi.yellow('▲ ${issues.length} hardcoded ${issues.length == 1 ? 'string' : 'strings'}'));
    }
    return ci && issues.isNotEmpty ? 1 : 0;
  }
}

class _InitCommand extends _Base {
  _InitCommand(super.env) {
    argParser.addFlag('force', negatable: false, help: 'Overwrite an existing $configFileName.');
  }

  @override
  String get name => 'init';

  @override
  String get description => 'Write $configFileName with the detected folder, base locale and format.';

  @override
  Future<int> run() async {
    final pr = loadProject();
    final file = File(p.join(pr.root, configFileName));
    if (file.existsSync() && !(a['force'] as bool)) {
      throw TranslyException('$configFileName already exists (use --force to replace it)');
    }
    final text = TranslyConfig(
      dir: pr.relativeDir.replaceAll(r'\', '/'),
      base: pr.base.locale,
      format: pr.format,
      sources: pr.config.sources,
      ignoreKeys: pr.config.ignoreKeys,
      ignoreUntranslated: pr.config.ignoreUntranslated,
    ).toYaml();
    file.writeAsStringSync(text);
    if (json) {
      out.writeln(prettyJson({...projectJson(pr), 'written': configFileName}));
    } else {
      out.writeln('${ansi.green('✔')} Wrote $configFileName');
      out.write(ansi.gray(text));
    }
    return 0;
  }
}
