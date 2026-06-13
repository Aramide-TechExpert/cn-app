import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/settings_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ClustezApp extends ConsumerWidget {
  const ClustezApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      title: 'Clustez',
      // Show the red DEBUG ribbon on debug builds — an unmistakable tell that
      // this is the Flutter build (RN had none). Auto-hidden in release.
      debugShowCheckedModeBanner: true,
      theme: buildClustezTheme(Brightness.light),
      darkTheme: buildClustezTheme(Brightness.dark),
      themeMode: settings.themeMode,
      // User-chosen text size (Settings → Appearance) overrides the OS scale.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(settings.textScale)),
        child: child!,
      ),
      routerConfig: router,
    );
  }
}
