import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'sections.dart';

/// The languages of the app. Arabic is the source language.
const supportedLocales = [Locale('ar'), Locale('en'), Locale('fr'), Locale('de'), Locale('es')];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(localizedApp());
}

/// The app wrapped in [EasyLocalization].
Widget localizedApp({Locale startLocale = const Locale('ar')}) => EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: startLocale,
      child: const ShopApp(),
    );

/// The example shop. Arabic (right-to-left) by default; pick another
/// language in the app bar.
class ShopApp extends StatelessWidget {
  /// Creates the app.
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => 'app.appTitle'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0F766E), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

/// The tabs of the shop.
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
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
        title: Text('app.appTitle'.tr()),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.translate),
            tooltip: 'settings.language'.tr(),
            onSelected: context.setLocale,
            itemBuilder: (context) => [
              for (final locale in supportedLocales) PopupMenuItem(value: locale, child: Text(locale.toLanguageTag())),
            ],
          ),
        ],
      ),
      body: ListView(children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: 'nav.navHome'.tr()),
          NavigationDestination(icon: const Icon(Icons.grid_view), label: 'nav.navCategories'.tr()),
          NavigationDestination(icon: const Icon(Icons.shopping_cart_outlined), label: 'nav.navCart'.tr()),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: 'nav.navOrders'.tr()),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: 'nav.navProfile'.tr()),
        ],
      ),
    );
  }
}
