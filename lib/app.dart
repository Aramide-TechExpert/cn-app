import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class ClustezApp extends StatelessWidget {
  const ClustezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clustez',
      debugShowCheckedModeBanner: false,
      theme: buildClustezTheme(Brightness.light),
      darkTheme: buildClustezTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
