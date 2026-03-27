import 'package:flutter/widgets.dart';

/// 轻量级本地化文案
///
/// 说明：项目当前主要为中文文案，本类先提供核心公共文案的中英文切换能力，
/// 其余未覆盖文案会自动回退为 key 本身（通常即中文）。
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  static const Map<String, Map<String, String>> _values = {
    'zh': {
      'app.title': '互联网+护理服务',
      'settings.title': '偏好设置',
      'settings.theme': '深色模式',
      'settings.theme.system': '跟随系统',
      'settings.theme.light': '浅色模式',
      'settings.theme.dark': '深色模式',
      'settings.language': '语言',
      'settings.language.zh': '简体中文',
      'settings.language.en': 'English',
      'settings.accessibility': '老年友好模式',
      'settings.accessibility.subtitle': '增大字体并提升触控区域',
      'contract.service.title': '上门护理服务协议',
      'contract.nurse.title': '护士入职服务协议',
      'calendar.title': '护士工作日历',
      'calendar.save': '保存时段',
    },
    'en': {
      'app.title': 'Nursing Service',
      'settings.title': 'Preferences',
      'settings.theme': 'Dark Mode',
      'settings.theme.system': 'System',
      'settings.theme.light': 'Light',
      'settings.theme.dark': 'Dark',
      'settings.language': 'Language',
      'settings.language.zh': 'Chinese',
      'settings.language.en': 'English',
      'settings.accessibility': 'Senior-Friendly Mode',
      'settings.accessibility.subtitle': 'Larger text and touch targets',
      'contract.service.title': 'Home Nursing Service Agreement',
      'contract.nurse.title': 'Nurse Onboarding Agreement',
      'calendar.title': 'Nurse Work Calendar',
      'calendar.save': 'Save Slots',
    },
  };

  String t(String key) {
    final code = locale.languageCode.toLowerCase();
    return _values[code]?[key] ?? _values['zh']?[key] ?? key;
  }
}

extension AppLocalizationsContextX on BuildContext {
  String tr(String key) =>
      AppLocalizations(Localizations.localeOf(this)).t(key);
}
