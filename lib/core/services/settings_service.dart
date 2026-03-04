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
  static const String _hasSeenAuthKey = 'has_seen_auth';
  static const String _userNameKey = 'user_name';
  static const String _userTitleKey = 'user_title';
  static const String _showTimerIconKey = 'show_timer_icon';

  bool _isDarkMode = false;
  String _language = 'tr';
  Color _themeColor = const Color(0xFF195DE6);
  String _fieldOfStudy = 'Genel';
  bool _isLoggedIn = false;
  String? _userEmail;
  bool _hasSeenAuth = false;
  String? _userName;
  String? _userTitle;
  bool _showTimerIcon = true;

  static final ValueNotifier<int> activeSessionTime = ValueNotifier(0);

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  Color get themeColor => _themeColor;
  String get fieldOfStudy => _fieldOfStudy;
  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;
  bool get hasSeenAuth => _hasSeenAuth;
  String? get userName => _userName;
  String? get userTitle => _userTitle;
  bool get showTimerIcon => _showTimerIcon;

  /// All 20 supported languages: locale code → display name
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'zh': 'Mandarin Chinese',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'ar': 'Arabic',
    'bn': 'Bengali',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ur': 'Urdu',
    'id': 'Bahasa Indonesia',
    'de': 'Deutsch',
    'ja': 'Japanese',
    'pcm': 'Nigerian Pidgin',
    'mr': 'Marathi',
    'te': 'Telugu',
    'tr': 'Türkçe',
    'ta': 'Tamil',
    'vi': 'Vietnamese',
    'wuu': 'Wu Chinese',
  };

  String get languageLabel => supportedLanguages[_language] ?? 'Türkçe';

  /// AI response language instruction injected into every Gemini prompt.
  String get languagePromptInstruction {
    switch (_language) {
      case 'tr':
        return 'Cevabını Türkçe olarak ver. Basit, sade ve anlaşılır bir dil kullan.';
      case 'en':
        return 'Answer in English. Use simple, clear and easy-to-understand language.';
      case 'zh':
        return '请用中文普通话回答。使用简单、清晰、易于理解的语言。';
      case 'hi':
        return 'हिन्दी में उत्तर दें। सरल, स्पष्ट और समझने में आसान भाषा का उपयोग करें।';
      case 'es':
        return 'Responde en español. Usa un lenguaje simple, claro y fácil de entender.';
      case 'fr':
        return 'Réponds en français. Utilise un langage simple, clair et facile à comprendre.';
      case 'ar':
        return 'أجب باللغة العربية. استخدم لغة بسيطة وواضحة وسهلة الفهم.';
      case 'bn':
        return 'বাংলায় উত্তর দিন। সহজ, স্পষ্ট এবং বোধগম্য ভাষা ব্যবহার করুন।';
      case 'pt':
        return 'Responda em português. Use uma linguagem simples, clara e fácil de entender.';
      case 'ru':
        return 'Отвечай на русском языке. Используй простой, понятный и доступный язык.';
      case 'ur':
        return 'اردو میں جواب دیں۔ سادہ، واضح اور آسان زبان استعمال کریں۔';
      case 'id':
        return 'Jawab dalam bahasa Indonesia. Gunakan bahasa yang sederhana, jelas, dan mudah dipahami.';
      case 'de':
        return 'Antworte auf Deutsch. Verwende eine einfache, klare und leicht verständliche Sprache.';
      case 'ja':
        return '日本語で答えてください。シンプルで分かりやすい言葉を使ってください。';
      case 'pcm':
        return 'Answer in Nigerian Pidgin English. Make am simple and easy to understand.';
      case 'mr':
        return 'मराठीत उत्तर द्या. सोपी, स्पष्ट आणि समजण्यास सुलभ भाषा वापरा.';
      case 'te':
        return 'తెలుగులో సమాధానం ఇవ్వండి. సులభమైన, స్పష్టమైన భాష ఉపయోగించండి.';
      case 'ta':
        return 'தமிழில் பதில் சொல்லுங்கள். எளிய, தெளிவான மொழியைப் பயன்படுத்துங்கள்.';
      case 'vi':
        return 'Trả lời bằng tiếng Việt. Sử dụng ngôn ngữ đơn giản, rõ ràng và dễ hiểu.';
      case 'wuu':
        return '请用吴语（上海话）回答。使用简单清晰的语言。';
      default:
        return 'Answer in English. Use simple, clear and easy-to-understand language.';
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
    _hasSeenAuth = prefs.getBool(_hasSeenAuthKey) ?? false;
    _userName = prefs.getString(_userNameKey);
    _userTitle = prefs.getString(_userTitleKey);
    _showTimerIcon = prefs.getBool(_showTimerIconKey) ?? true;
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
    }
    notifyListeners();
  }

  Future<void> setHasSeenAuth(bool value) async {
    _hasSeenAuth = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenAuthKey, value);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
    notifyListeners();
  }

  Future<void> setUserTitle(String title) async {
    _userTitle = title;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userTitleKey, title);
    notifyListeners();
  }

  Future<void> setShowTimerIcon(bool value) async {
    _showTimerIcon = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTimerIconKey, value);
    notifyListeners();
  }
}
