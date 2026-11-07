import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'l10n_extension.dart';
import 'sections.dart';

void main() => runApp(const ShopApp());

/// The example shop. Pick a language in the app bar; Arabic switches the
/// whole layout to right-to-left.
class ShopApp extends StatefulWidget {
  /// Creates the app.
  const ShopApp({super.key, this.initialLocale});

  /// The starting locale (tests use this).
  final Locale? initialLocale;

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  late Locale? _locale = widget.initialLocale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0F766E), useMaterial3: true),
      home: HomeScreen(onLocale: (l) => setState(() => _locale = l)),
    );
  }
}

/// The tabs of the shop.
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({super.key, required this.onLocale});

  /// Called when the user picks a language.
  final ValueChanged<Locale> onLocale;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = switch (_tab) {
      0 => [...appTiles(context), ...homeTiles(context), ...onboardingTiles(context)],
      1 => [...categoriesTiles(context), ...productTiles(context)],
      2 => [...cartTiles(context), ...checkoutTiles(context)],
      3 => [...ordersTiles(context), ...notificationsTiles(context), ...daysTiles(context)],
      4 => [
          ...profileTiles(context),
          ...authTiles(context),
          ...miscTiles(context),
          ...settingsTiles(context),
          ...errorsTiles(context),
          ...commonTiles(context)
        ],
      _ => <Widget>[],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.translate),
            tooltip: l10n.language,
            onSelected: widget.onLocale,
            itemBuilder: (context) => [
              for (final locale in AppLocalizations.supportedLocales)
                PopupMenuItem(value: locale, child: Text(locale.toLanguageTag())),
            ],
          ),
        ],
      ),
      body: ListView(children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.grid_view), label: l10n.navCategories),
          NavigationDestination(icon: const Icon(Icons.shopping_cart_outlined), label: l10n.navCart),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: l10n.navOrders),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: l10n.navProfile),
        ],
      ),
    );
  }
}
