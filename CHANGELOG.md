## 0.1.0

First release.

- `check`: compares every locale with the base locale: missing and extra keys, empty and TODO values, text identical to the base, placeholder and ICU plural/select mismatches, duplicate keys and invalid JSON with line numbers.
- Code checks in `check`: keys referenced in Dart that do not exist (with "did you mean"), wrong placeholder arguments (gen-l10n methods, easy_localization `args`/`namedArgs`), unused keys, hardcoded user-facing strings.
- `fix`: adds missing keys to every locale in base order, keeps every existing value, `--remove-extra`, `--dry-run` diff.
- `add <locale>`: creates a new locale file from the base, metadata included, optionally machine-translated.
- `translate`: free machine translation (no API key) that keeps placeholders and ICU plurals intact, with retry, rate limiting and a review list.
- `unused`, `hardcoded`, `init` commands.
- `.arb` (gen-l10n) and flat or nested `.json` (easy_localization) files; folder found from `l10n.yaml`, `transly.yaml` or common paths.
- Colored terminal report, `--json` output, `--ci` exit codes and GitHub Actions annotations.
