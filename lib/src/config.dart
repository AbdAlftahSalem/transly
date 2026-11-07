/// Project configuration: `transly.yaml`, `l10n.yaml` and folder discovery.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'locale_name.dart';
import 'translation_file.dart';
import 'version.dart';

/// A problem that stops a command, with the process exit code to use.
class TranslyException implements Exception {
  /// Creates the exception.
  const TranslyException(this.message, {this.exitCode = 64});

  /// What went wrong, in plain words.
  final String message;

  /// The exit code (64 usage, 65 bad data, 66 no input).
  final int exitCode;

  @override
  String toString() => message;
}

/// Settings from `transly.yaml` and/or the command line.
class TranslyConfig {
  /// Creates a config. Null fields mean "not set here".
  const TranslyConfig({
    this.dir,
    this.base,
    this.format,
    this.sources,
    this.ignoreKeys,
    this.ignoreUntranslated,
    this.ignoreFiles,
    this.accessors,
  });

  /// Reads `transly.yaml` text.
  factory TranslyConfig.fromYaml(String text, {String source = configFileName}) {
    final Object? doc;
    try {
      doc = loadYaml(text);
    } on YamlException catch (e) {
      throw TranslyException('$source is not valid YAML: ${e.message}', exitCode: 65);
    }
    if (doc == null) return const TranslyConfig();
    if (doc is! Map) throw TranslyException('$source must be a YAML map', exitCode: 65);
    final map = doc;
    List<String>? list(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is String) return [v];
      if (v is List) return v.map((e) => '$e').toList();
      throw TranslyException('$source: "$key" must be a list', exitCode: 65);
    }

    final format = map['format'];
    final fmt = format == null || format == 'auto' ? null : TranslationFormat.tryParse('$format');
    if (format != null && format != 'auto' && fmt == null) {
      throw TranslyException('$source: format must be arb, json or auto', exitCode: 65);
    }
    return TranslyConfig(
      dir: map['dir']?.toString(),
      base: map['base']?.toString(),
      format: fmt,
      sources: list('sources'),
      ignoreKeys: list('ignore_keys'),
      ignoreUntranslated: list('ignore_untranslated'),
      ignoreFiles: list('ignore_files'),
      accessors: list('accessors'),
    );
  }

  /// The translations folder, relative to the project root.
  final String? dir;

  /// The base (source of truth) locale.
  final String? base;

  /// The file format; null means auto-detect.
  final TranslationFormat? format;

  /// Folders with Dart code to scan (default `lib`).
  final List<String>? sources;

  /// Keys to skip everywhere. `*` and `?` wildcards work.
  final List<String>? ignoreKeys;

  /// Keys allowed to equal the base value (brand names, "OK", ...).
  final List<String>? ignoreUntranslated;

  /// Dart files to skip when scanning code (globs relative to the root).
  final List<String>? ignoreFiles;

  /// Extra names that hold a localizations object in code, e.g. `t` for
  /// `t.helloWorld` or `context.loc`.
  final List<String>? accessors;

  /// Fields set in [other] win over this config's fields.
  TranslyConfig merge(TranslyConfig other) => TranslyConfig(
        dir: other.dir ?? dir,
        base: other.base ?? base,
        format: other.format ?? format,
        sources: other.sources ?? sources,
        ignoreKeys: [...?ignoreKeys, ...?other.ignoreKeys],
        ignoreUntranslated: [...?ignoreUntranslated, ...?other.ignoreUntranslated],
        ignoreFiles: [...?ignoreFiles, ...?other.ignoreFiles],
        accessors: [...?accessors, ...?other.accessors],
      );

  /// This config as `transly.yaml` text.
  String toYaml() {
    final b = StringBuffer('# $toolName settings. Command-line options win over this file.\n');
    if (dir != null) b.writeln('dir: $dir');
    if (base != null) b.writeln('base: $base');
    b.writeln('format: ${format?.name ?? 'auto'}');
    b.writeln('sources: [${(sources ?? const ['lib']).join(', ')}]');
    b.writeln('# Keys skipped everywhere (wildcards allowed), e.g. [app_name, "debug_*"]');
    b.writeln('ignore_keys: [${(ignoreKeys ?? const []).join(', ')}]');
    b.writeln('# Keys allowed to be the same as the base text (brand names, "OK")');
    b.writeln('ignore_untranslated: [${(ignoreUntranslated ?? const []).join(', ')}]');
    return b.toString();
  }
}

/// Settings read from Flutter's `l10n.yaml`.
class L10nYaml {
  /// Creates the settings.
  const L10nYaml({required this.arbDir, required this.templateArbFile, required this.outputClass});

  /// Reads `l10n.yaml` in [root], or returns null when there is none.
  static L10nYaml? read(String root) {
    final file = File(p.join(root, 'l10n.yaml'));
    if (!file.existsSync()) return null;
    Object? doc;
    try {
      doc = loadYaml(file.readAsStringSync());
    } on YamlException catch (e) {
      throw TranslyException('l10n.yaml is not valid YAML: ${e.message}', exitCode: 65);
    }
    final map = doc is Map ? doc : const {};
    return L10nYaml(
      arbDir: (map['arb-dir'] ?? 'lib/l10n').toString(),
      templateArbFile: (map['template-arb-file'] ?? 'app_en.arb').toString(),
      outputClass: (map['output-class'] ?? 'AppLocalizations').toString(),
    );
  }

  /// `arb-dir` (default `lib/l10n`).
  final String arbDir;

  /// `template-arb-file` (default `app_en.arb`).
  final String templateArbFile;

  /// `output-class` (default `AppLocalizations`).
  final String outputClass;
}

/// Folders searched, in order, when nothing says where translations live.
const List<String> commonTranslationDirs = [
  'lib/l10n',
  'lib/l10n/arb',
  'assets/translations',
  'assets/lang',
  'assets/langs',
  'assets/i18n',
  'assets/l10n',
  'assets/locales',
  'lib/i18n',
  'i18n',
  'translations',
];

/// A project with its translation files loaded.
class TranslyProject {
  TranslyProject._({
    required this.root,
    required this.dir,
    required this.dirSource,
    required this.format,
    required this.files,
    required this.base,
    required this.baseSource,
    required this.config,
    required this.l10n,
    required this.skipped,
  });

  /// The project root (absolute).
  final String root;

  /// The translations folder (absolute).
  final String dir;

  /// How the folder was found, e.g. `l10n.yaml`, `--dir`, `found`.
  final String dirSource;

  /// The format of the translation files.
  final TranslationFormat format;

  /// Every translation file, base first, then by locale.
  final List<TranslationFile> files;

  /// The base file.
  final TranslationFile base;

  /// How the base was chosen.
  final String baseSource;

  /// The effective settings.
  final TranslyConfig config;

  /// `l10n.yaml`, when the project has one.
  final L10nYaml? l10n;

  /// Files in the folder that were skipped (no locale in the name).
  final List<String> skipped;

  /// The other (non-base) files.
  Iterable<TranslationFile> get targets => files.where((f) => !identical(f, base));

  /// The folder relative to the root, for display.
  String get relativeDir => p.relative(dir, from: root);

  /// A path relative to the root, for display.
  String relative(String path) => p.relative(path, from: root);

  /// The file for [locale], or null.
  TranslationFile? fileFor(String locale) {
    final want = normalizeLocale(locale);
    for (final f in files) {
      if (normalizeLocale(f.locale) == want) return f;
    }
    return null;
  }

  /// Finds the translations folder and loads every file in it.
  ///
  /// The folder comes from, in order: [cli] `dir`, `transly.yaml` `dir`,
  /// `l10n.yaml` `arb-dir`, then the first of [commonTranslationDirs] that
  /// holds `.arb` or `.json` files.
  static TranslyProject load({required String root, TranslyConfig cli = const TranslyConfig()}) {
    final absRoot = p.normalize(p.absolute(root));
    if (!Directory(absRoot).existsSync()) {
      throw TranslyException('the project folder $root does not exist', exitCode: 66);
    }
    final configFile = File(p.join(absRoot, configFileName));
    var config =
        configFile.existsSync() ? TranslyConfig.fromYaml(configFile.readAsStringSync()) : const TranslyConfig();
    final hasConfigDir = config.dir != null;
    config = config.merge(cli);
    final l10n = L10nYaml.read(absRoot);

    String dir;
    String dirSource;
    if (cli.dir != null) {
      dir = cli.dir!;
      dirSource = '--dir';
    } else if (hasConfigDir) {
      dir = config.dir!;
      dirSource = configFileName;
    } else if (l10n != null) {
      dir = l10n.arbDir;
      dirSource = 'l10n.yaml';
    } else {
      final found = commonTranslationDirs.where((d) => _hasTranslations(p.join(absRoot, d), config.format));
      if (found.isEmpty) {
        throw TranslyException(
          'no translation folder found. Looked in ${commonTranslationDirs.join(', ')}.\n'
          'Pass --dir <folder> or run "$toolName init --dir <folder>".',
          exitCode: 66,
        );
      }
      dir = found.first;
      dirSource = 'found';
    }
    final absDir = p.normalize(p.isAbsolute(dir) ? dir : p.join(absRoot, dir));
    if (!Directory(absDir).existsSync()) {
      throw TranslyException('the translations folder $dir does not exist ($dirSource)', exitCode: 66);
    }

    final all = Directory(absDir).listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    final arbs = all.where((f) => f.path.toLowerCase().endsWith('.arb')).toList();
    final jsons = all.where((f) => f.path.toLowerCase().endsWith('.json')).toList();
    final format = config.format ?? (arbs.isNotEmpty ? TranslationFormat.arb : TranslationFormat.json);
    final candidates = format == TranslationFormat.arb ? arbs : jsons;
    final files = <TranslationFile>[];
    final skipped = <String>[];
    for (final f in candidates) {
      final name = p.basename(f.path);
      if (name.startsWith('.')) continue;
      final tf = TranslationFile.load(f.path, format: format);
      if (tf.fileLocale == null && tf.globals['@@locale'] is! String) {
        skipped.add(name);
        continue;
      }
      files.add(tf);
    }
    if (files.isEmpty) {
      throw TranslyException(
          'no ${format.extension} translation files with a locale in their name in ${p.relative(absDir, from: absRoot)}',
          exitCode: 66);
    }

    TranslationFile? base;
    String baseSource;
    if (config.base != null) {
      final want = normalizeLocale(config.base!);
      base = files.where((f) => normalizeLocale(f.locale) == want).firstOrNull;
      if (base == null) {
        throw TranslyException(
          'the base locale "${config.base}" has no file in ${p.relative(absDir, from: absRoot)} '
          '(found: ${files.map((f) => f.locale).join(', ')})',
        );
      }
      baseSource = cli.base != null ? '--base' : configFileName;
    } else if (l10n != null &&
        format == TranslationFormat.arb &&
        files.any((f) => f.fileName == l10n.templateArbFile)) {
      base = files.firstWhere((f) => f.fileName == l10n.templateArbFile);
      baseSource = 'l10n.yaml template';
    } else if (files.any((f) => languageOf(f.locale) == 'en' && f.locale.length == 2)) {
      base = files.firstWhere((f) => languageOf(f.locale) == 'en' && f.locale.length == 2);
      baseSource = 'default en';
    } else {
      base = files.first;
      baseSource = 'first file';
    }
    final others = files.where((f) => !identical(f, base)).toList()..sort((a, b) => a.locale.compareTo(b.locale));
    final ordered = [base, ...others];
    return TranslyProject._(
      root: absRoot,
      dir: absDir,
      dirSource: dirSource,
      format: format,
      files: ordered,
      base: base,
      baseSource: baseSource,
      config: config,
      l10n: l10n,
      skipped: skipped,
    );
  }

  static bool _hasTranslations(String dir, TranslationFormat? format) {
    final d = Directory(dir);
    if (!d.existsSync()) return false;
    return d.listSync().whereType<File>().any((f) {
      final ext = p.extension(f.path).toLowerCase();
      if (format != null) return ext == format.extension;
      return ext == '.arb' || ext == '.json';
    });
  }
}

/// Matches keys against patterns with `*` and `?` wildcards.
class KeyMatcher {
  /// Creates a matcher for [patterns].
  KeyMatcher(Iterable<String> patterns)
      : _exact = patterns.where((x) => !x.contains('*') && !x.contains('?')).toSet(),
        _globs = patterns
            .where((x) => x.contains('*') || x.contains('?'))
            .map((x) => RegExp('^${RegExp.escape(x).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$'))
            .toList();

  final Set<String> _exact;
  final List<RegExp> _globs;

  /// Whether [key] matches any pattern.
  bool matches(String key) => _exact.contains(key) || _globs.any((g) => g.hasMatch(key));
}
