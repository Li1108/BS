import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final bool seniorMode;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('zh', 'CN'),
    this.seniorMode = false,
  });

  double get textScaleFactor => seniorMode ? 1.15 : 1.0;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? seniorMode,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      seniorMode: seniorMode ?? this.seniorMode,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    _load();
  }

  static const String _storageKey = 'app_settings';

  Future<void> _load() async {
    final raw = StorageService.instance.getCache(_storageKey);
    if (raw is! Map) return;

    final themeRaw = raw['themeMode']?.toString() ?? 'system';
    final langRaw = raw['languageCode']?.toString() ?? 'zh';
    final countryRaw = raw['countryCode']?.toString() ?? 'CN';
    final seniorRaw = raw['seniorMode'] == true;

    state = state.copyWith(
      themeMode: switch (themeRaw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: Locale(langRaw, countryRaw),
      seniorMode: seniorRaw,
    );
  }

  Future<void> _persist() async {
    final themeValue = switch (state.themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await StorageService.instance.saveCache(_storageKey, {
      'themeMode': themeValue,
      'languageCode': state.locale.languageCode,
      'countryCode': state.locale.countryCode,
      'seniorMode': state.seniorMode,
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _persist();
  }

  Future<void> setSeniorMode(bool value) async {
    state = state.copyWith(seniorMode: value);
    await _persist();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
      return AppSettingsNotifier();
    });
