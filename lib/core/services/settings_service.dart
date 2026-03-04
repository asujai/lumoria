import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._init();
  factory SettingsService() => _instance;
  SettingsService._init();

  static const String _darkModeKey = 'dark_mode';
  static const String _languageKey = 'language';
  static const String _themeColorKey = 'theme_color';
  static const String _fieldOfStudyKey = 'field_of_study';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';
  static const String _isPremiumKey = 'is_premium';
  static const String _hasSeenAuthKey = 'has_seen_auth';

  bool _isDarkMode = false;
  String _language = 'tr';
  Color _themeColor = const Color(0xFF195DE6); // Varsayılan mavi
  String _fieldOfStudy = 'Genel';

  bool _isLoggedIn = false;
  String? _userEmail;
  bool _isPremium = false;
  bool _hasSeenAuth = false;

  static final ValueNotifier<int> activeSessionTime = ValueNotifier(0);

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  Color get themeColor => _themeColor;
  String get fieldOfStudy => _fieldOfStudy;
  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;
  bool get isPremium => _isPremium;
  bool get hasSeenAuth => _hasSeenAuth;

  String get languageLabel {
    switch (_language) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      default:
        return 'Türkçe';
    }
  }

  String get languagePromptInstruction {
    switch (_language) {
      case 'tr':
        return 'Cevabını Türkçe olarak ver. Basit, sade ve anlaşılır bir dil kullan.';
      case 'en':
        return 'Answer in English. Use simple, clear and easy-to-understand language.';
      case 'de':
        return 'Antworte auf Deutsch. Verwende eine einfache, klare und leicht verständliche Sprache.';
      default:
        return 'Cevabını Türkçe olarak ver. Basit, sade ve anlaşılır bir dil kullan.';
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _language = prefs.getString(_languageKey) ?? 'tr';
    _fieldOfStudy = prefs.getString(_fieldOfStudyKey) ?? 'Genel';
    final colorValue = prefs.getInt(_themeColorKey);
    if (colorValue != null) {
      _themeColor = Color(colorValue);
    }
    _isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    _userEmail = prefs.getString(_userEmailKey);
    _isPremium = prefs.getBool(_isPremiumKey) ?? false;
    _hasSeenAuth = prefs.getBool(_hasSeenAuthKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeColorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setFieldOfStudy(String field) async {
    _fieldOfStudy = field;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fieldOfStudyKey, field);
    notifyListeners();
  }

  Future<void> setLoggedIn(bool value, {String? email}) async {
    _isLoggedIn = value;
    _userEmail = email;
    _hasSeenAuth = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
    await prefs.setBool(_hasSeenAuthKey, true);
    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    } else {
      await prefs.remove(_userEmailKey);
      await setPremium(false); // Clear premium state on logout
    }
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, value);
    notifyListeners();
  }

  Future<void> setHasSeenAuth(bool value) async {
    _hasSeenAuth = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenAuthKey, value);
    notifyListeners();
  }
}
