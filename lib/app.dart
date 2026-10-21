import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/feed_controller.dart' show apiClientProvider;
import 'data/refresh.dart';
import 'data/settings_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'utils/remote_settings.dart';

/// Full-screen gate for maintenance mode / forced update (News Loop Control).
class _LifecycleGate extends StatelessWidget {
  const _LifecycleGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: maintenanceNotice,
      builder: (context, maintenance, _) =>
          ValueListenableBuilder<bool>(
        valueListenable: updateRequired,
        builder: (context, mustUpdate, __) {
          if (maintenance == null && !mustUpdate) return child;
          final (emoji, title, body) = maintenance != null
              ? ('🛠️', 'Under maintenance', maintenance)
              : (
                  '⬆️',
                  'Update required',
                  'This version of News Loop is out of date. Please install the latest build to continue.'
                );
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 44)),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(body,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewsLoopApp extends ConsumerStatefulWidget {
  const NewsLoopApp({super.key});

  @override
  ConsumerState<NewsLoopApp> createState() => _NewsLoopAppState();
}

class _NewsLoopAppState extends ConsumerState<NewsLoopApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Admin Control-panel changes must reach RUNNING apps, not only cold
    // launches: re-fetch the served config on every return to foreground
    // (throttled) and refresh all content if it changed.
    if (state == AppLifecycleState.resumed) {
      fetchAndApplyRemoteConfig(
        ref.read(apiClientProvider),
        invalidateOnChange: ref.invalidate,
        minInterval: const Duration(minutes: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the auth listener alive: preference saves / sign in / sign out
    // auto-refresh every content surface (no manual pull-to-refresh).
    ref.watch(preferenceRefreshListener);
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      title: 'News Loop',
      // Show the red DEBUG ribbon on debug builds — an unmistakable tell that
      // this is the Flutter build (RN had none). Auto-hidden in release.
      debugShowCheckedModeBanner: true,
      theme: buildNewsLoopTheme(Brightness.light),
      darkTheme: buildNewsLoopTheme(Brightness.dark),
      themeMode: settings.themeMode,
      // User-chosen text size (Settings → Appearance) overrides the OS scale.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(settings.textScale)),
        child: _LifecycleGate(child: child!),
      ),
      routerConfig: router,
    );
  }
}
