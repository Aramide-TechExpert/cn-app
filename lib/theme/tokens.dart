import 'package:flutter/material.dart';

/// Spacing scale (4pt base).
abstract class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2 = 24;
  static const double x3 = 32;
  static const double x4 = 48;
}

/// Corner radii.
abstract class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Clustez color tokens, exposed via [ThemeExtension] so widgets read them with
/// `Theme.of(context).extension<ClustezColors>()!`. Mirrors the RN design system.
@immutable
class ClustezColors extends ThemeExtension<ClustezColors> {
  final Color bg;
  final Color bgElevated;
  final Color bgInset;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textFaint;
  final Color brand;
  final Color brandPressed;
  final Color onBrand;
  final Color brandSoft;
  final Color accent;
  final Color critical;
  final Color high;
  final Color medium;
  final Color low;
  final Color breaking;
  final Color success;

  const ClustezColors({
    required this.bg,
    required this.bgElevated,
    required this.bgInset,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textFaint,
    required this.brand,
    required this.brandPressed,
    required this.onBrand,
    required this.brandSoft,
    required this.accent,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    required this.breaking,
    required this.success,
  });

  /// Signal color for an article impact level.
  Color impact(String level) {
    switch (level) {
      case 'Critical':
        return critical;
      case 'High':
        return high;
      case 'Medium':
        return medium;
      default:
        return low;
    }
  }

  static const ClustezColors light = ClustezColors(
    bg: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    bgInset: Color(0xFFF6F7F9),
    border: Color(0xFFECEEF1),
    text: Color(0xFF11141A),
    textSecondary: Color(0xFF5A6172),
    textFaint: Color(0xFF8B92A1),
    brand: Color(0xFF2D6BFF),
    brandPressed: Color(0xFF1F54E0),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFEAF1FF),
    accent: Color(0xFFFF5A5F),
    critical: Color(0xFFE5484D),
    high: Color(0xFFF76808),
    medium: Color(0xFF2D6BFF),
    low: Color(0xFF8B8D98),
    breaking: Color(0xFFE5484D),
    success: Color(0xFF30A46C),
  );

  static const ClustezColors dark = ClustezColors(
    bg: Color(0xFF0B0D12),
    bgElevated: Color(0xFF12151C),
    bgInset: Color(0xFF1A1E27),
    border: Color(0xFF262B36),
    text: Color(0xFFF4F6FA),
    textSecondary: Color(0xFFA6ADBC),
    textFaint: Color(0xFF6B7280),
    brand: Color(0xFF2D6BFF),
    brandPressed: Color(0xFF7FA8FF),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFF16203A),
    accent: Color(0xFFFF5A5F),
    critical: Color(0xFFE5484D),
    high: Color(0xFFF76808),
    medium: Color(0xFF7FA8FF),
    low: Color(0xFF8B8D98),
    breaking: Color(0xFFE5484D),
    success: Color(0xFF30A46C),
  );

  @override
  ClustezColors copyWith({
    Color? bg,
    Color? bgElevated,
    Color? bgInset,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? textFaint,
    Color? brand,
    Color? brandPressed,
    Color? onBrand,
    Color? brandSoft,
    Color? accent,
    Color? critical,
    Color? high,
    Color? medium,
    Color? low,
    Color? breaking,
    Color? success,
  }) {
    return ClustezColors(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      bgInset: bgInset ?? this.bgInset,
      border: border ?? this.border,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      brand: brand ?? this.brand,
      brandPressed: brandPressed ?? this.brandPressed,
      onBrand: onBrand ?? this.onBrand,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      critical: critical ?? this.critical,
      high: high ?? this.high,
      medium: medium ?? this.medium,
      low: low ?? this.low,
      breaking: breaking ?? this.breaking,
      success: success ?? this.success,
    );
  }

  @override
  ClustezColors lerp(ThemeExtension<ClustezColors>? other, double t) {
    if (other is! ClustezColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor.
extension ClustezColorsX on BuildContext {
  ClustezColors get colors => Theme.of(this).extension<ClustezColors>()!;
}
