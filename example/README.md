# transly examples

Two copies of the same shop app, 168 messages in five languages, so you can try every command on a real project:

| Folder | Library | Files | Base language |
| --- | --- | --- | --- |
| [`shop_arb`](shop_arb) | Flutter gen-l10n | `lib/l10n/app_*.arb` (ICU plurals, selects, `@metadata`) | English |
| [`shop_json`](shop_json) | easy_localization | `assets/translations/*.json` (nested keys, plural maps) | Arabic |

Both apps are clean: `transly check --ci --fail-on warning` passes, and `flutter analyze`, `flutter test` and `flutter build web` pass. Every key is used in the code, Arabic switches the layout to right-to-left.

The French, German, Spanish and Arabic texts were produced with `transly translate` (free machine translation). They are still marked for review, so `check` shows them in the "To review" column. Have a native speaker check them before you ship anything like this.

```bash
cd example/shop_arb
flutter pub get
dart run transly check        # all good, 671 machine translations to review
dart run transly add it --translate
flutter run -d chrome
```

Copies with planted problems (missing keys, broken placeholders, a duplicate key, invalid JSON, typos in key names, wrong arguments, unused keys, hardcoded strings) live in [`test/fixtures`](../test/fixtures) and the integration tests check that transly finds exactly those.

[`example.dart`](example.dart) shows the Dart API.
