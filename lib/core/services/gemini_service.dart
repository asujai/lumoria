import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'secure_storage_service.dart';
import 'settings_service.dart';

class GeminiService {
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _model = 'gemini-2.5-flash';

  Future<String> _getApiKey() async {
    final localApiKey = await _storageService.getApiKey();
    if (localApiKey != null && localApiKey.isNotEmpty) {
      return localApiKey;
    }
    return Env.apiKey;
  }

  Future<String> explainContextualText(String selectedText) async {
    try {
      final apiKey = await _getApiKey();

      if (apiKey.isEmpty) {
        throw Exception('API Anahtarı bulunamadı.');
      }

      final langInstruction = _settingsService.languagePromptInstruction;
      final fieldOfStudy = _settingsService.fieldOfStudy;

      final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''
$langInstruction

Aşağıdaki kelime veya kelime grubunun anlamını sade, net ve eksiksiz bir şekilde açıkla.
Kullanıcının Seçtiği Çalışma Alanı: "$fieldOfStudy"
Lütfen kelimeyi öncelikli olarak bu çalışma alanındaki (eğer varsa) anlamıyla açıkla. Eğer bu alanla ilgili özel bir anlamı yoksa, kelimenin en yaygın genel anlamını ver.
Sadece hedeflenen anlamı ver; gereksiz ansiklopedik veya süslü detaylardan, derin teknik analizlerden kaçın. Cevap mümkün olduğunca kısa ve öz olsun.
Fakat AÇIKLAMANIN ASLA YARIM KALMAMASINA ve cümlenin mantıklı bir şekilde tamamlanmasına ÇOK DİKKAT ET.
Metin:
"$selectedText"
'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 1024,
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'Açıklama üretilemedi.';
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? 'Bilinmeyen hata';
        throw Exception('Gemini API Hatası: $errorMsg');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Analiz sırasında bir hata oluştu: $e');
    }
  }
}
