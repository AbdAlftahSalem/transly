import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';

/// `context.l10n.someKey` instead of `AppLocalizations.of(context).someKey`.
extension L10nContext on BuildContext {
  /// The localized strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
