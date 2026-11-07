import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_json/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
  });

  for (final (locale, title, direction) in [
    ('ar', 'متجر سوق', TextDirection.rtl),
    ('en', 'Souq Shop', TextDirection.ltr),
    ('fr', null, TextDirection.ltr),
    ('de', null, TextDirection.ltr),
    ('es', null, TextDirection.ltr),
  ]) {
    testWidgets('every tab renders in $locale', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(localizedApp(startLocale: Locale(locale)));
        for (var i = 0; i < 20 && find.byType(ListView).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      if (title != null) expect(find.text(title), findsWidgets);
      expect(Directionality.of(tester.element(find.byType(ListView))), direction);
      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byType(NavigationDestination).at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
