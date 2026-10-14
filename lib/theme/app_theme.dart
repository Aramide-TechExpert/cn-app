import 'package:flutter/material.dart';
import 'tokens.dart';

/// Builds the [ThemeData] for a brightness from the Cluster News tokens.
ThemeData buildClusterNewsTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? ClusterNewsColors.dark
      : ClusterNewsColors.light;

  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.brand,
      brightness: brightness,
    ).copyWith(
      surface: c.bg,
      primary: c.brand,
      onPrimary: c.onBrand,
    ),
    extensions: <ThemeExtension<dynamic>>[c],
    textTheme: base.textTheme.apply(
      bodyColor: c.text,
      displayColor: c.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bgElevated,
      indicatorColor: c.brandSoft,
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgElevated,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: c.border,
  );
}

/// Shared text styles (paired with `context.colors` for color).
abstract class AppText {
  static const display = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
  static const title = TextStyle(
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
  static const headline = TextStyle(
    fontSize: 18,
    height: 1.33,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(fontSize: 15, height: 1.4);
  static const bodyStrong =
      TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600);
  static const callout =
      TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500);
  static const caption =
      TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500);
  static const micro = TextStyle(
    fontSize: 11,
    height: 1.27,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
}
