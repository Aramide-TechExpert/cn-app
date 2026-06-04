import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class ClustezApp extends StatelessWidget {
  const ClustezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clustez',
      // Show the red DEBUG ribbon on debug builds — an unmistakable tell that
      // this is the Flutter build (RN had none). Auto-hidden in release.
      debugShowCheckedModeBanner: true,
      theme: buildClustezTheme(Brightness.light),
      darkTheme: buildClustezTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
