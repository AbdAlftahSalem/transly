import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    debugPrint('building home'); // not user-facing
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Column(
        children: [
          Text(AppLocalizations.of(context)!.welcome('Abd')),
          Text(l10n.cartItems(3)),
          Text(l10n.greeting('male', 'Abd')),
          Text(l10n.settings),
          Text(context.l10n.signOut),
          Text(l10n.setings),
          Text(l10n.welcome()),
          Text(l10n.deleteAccount),
          Text('Buy now'),
          Text('Ignored on purpose'), // transly:ignore
          // transly:ignore
          Text('Also ignored'),
          const Text('assets/images/logo.png'),
          Text('${l10n.ok} 42'),
          IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: () {}),
          TextField(decoration: InputDecoration(hintText: 'Search products')),
          Text(l10n.ok),
        ],
      ),
    );
  }
}
