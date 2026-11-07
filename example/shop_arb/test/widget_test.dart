import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_arb/main.dart';

void main() {
  for (final (locale, title, direction) in [
    ('en', 'Souq Shop', TextDirection.ltr),
    ('ar', 'متجر سوق', TextDirection.rtl),
    ('fr', null, TextDirection.ltr),
    ('de', null, TextDirection.ltr),
    ('es', null, TextDirection.ltr),
  ]) {
    testWidgets('every tab renders in $locale', (tester) async {
      await tester.pumpWidget(ShopApp(initialLocale: Locale(locale)));
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
