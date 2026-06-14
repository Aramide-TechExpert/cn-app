import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-only app preferences (theme + text size) — the app-side of the
/// web Settings "Appearance" section. Persisted with shared_preferences so the
/// choice survives restarts. (Account/email-digest prefs live in Supabase and
/// are handled in the Settings screen directly.)
class AppSettings {
  // firstRunSeen defaults true so returning users never flash the first-run
  // banner before prefs load; _load() flips it false only for genuinely new
  // users (no stored key).
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.firstRunSeen = true,
  });
  final ThemeMode themeMode;
  final double textScale;
  final bool firstRunSeen;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? firstRunSeen,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        firstRunSeen: firstRunSeen ?? this.firstRunSeen,
      );
}

const _kThemeMode = 'clustez:themeMode';
const _kTextScale = 'clustez:textScale';
const _kFirstRun = 'clustez:firstRunSeen';

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      themeMode: switch (_prefs!.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      textScale: _prefs!.getDouble(_kTextScale) ?? 1.0,
      firstRunSeen: _prefs!.getBool(_kFirstRun) ?? false,
    );
  }

  Future<void> markFirstRunSeen() async {
    state = state.copyWith(firstRunSeen: true);
    await _ensure();
    await _prefs!.setBool(_kFirstRun, true);
  }

  Future<void> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _ensure();
    await _prefs!.setString(_kThemeMode, mode.name);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScale: scale);
    await _ensure();
    await _prefs!.setDouble(_kTextScale, scale);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
