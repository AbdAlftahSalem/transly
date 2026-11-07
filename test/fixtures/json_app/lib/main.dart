import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('home.title'.tr()),
        Text(tr('home.welcome', namedArgs: {'name': 'Abd'})),
        Text('cart.items'.plural(3)),
        Text('cart.checkout'.tr()),
        Text('errors.$code'.tr()),
        Text(tr('home.welcom')),
        Text('home.welcome'.tr()),
        Text('profile.edit'.tr(args: ['x'])),
        Text('about'.tr()),
        Text('brand'.tr()),
        Text('Hardcoded here'),
        ElevatedButton(onPressed: () {}, child: const Text('حفظ')),
      ],
    );
  }
}
