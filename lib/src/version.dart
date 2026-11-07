/// The package and executable name. Change it here and in `pubspec.yaml`.
const String toolName = 'transly';

/// The package version, kept in sync with `pubspec.yaml` (a test checks it).
const String toolVersion = '0.1.0';

/// The optional project config file read from the project root.
const String configFileName = '$toolName.yaml';

/// The marker that silences hardcoded-string and code-usage findings.
///
/// `// transly:ignore` on the same line or on the line above,
/// `// transly:ignore-file` anywhere in a file.
const String ignoreMarker = '$toolName:ignore';

/// File-level variant of [ignoreMarker].
const String ignoreFileMarker = '$toolName:ignore-file';

/// The sidecar file that lists machine-translated entries awaiting review.
const String reviewFileName = '.${toolName}_review.json';
