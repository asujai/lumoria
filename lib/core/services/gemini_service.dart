import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';
import 'settings_service.dart';
import 'purchase_service.dart';

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
    throw Exception('gemini_err_no_key_desc'.tr());
  }

  Future<String> explainContextualText(String selectedText) async {
    return "API maliyetlerini önlemek için bu özellik geçici olarak devre dışı bırakılmıştır.";
    try {
      final langInstruction = _settingsService.languagePromptInstruction;
      final fieldOfStudy = _settingsService.fieldOfStudy;

      final contentParams = {
        'contents': [
          {
            'parts': [
              {
                'text': 'prompt_template'.tr(namedArgs: {
                  'langInstruction': langInstruction,
                  'fieldOfStudy': fieldOfStudy,
                  'selectedText': selectedText,
                })
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 1024,
        }
      };

      // Eğer kullanıcı Premium ise (RevenueCat), doğrudan Supabase Edge Function çağırılır 
      // API Key mobilde saklanmaz, Backend'den (Supabase) işlenir.
      if (PurchaseService().isPremium) {
        final response = await Supabase.instance.client.functions.invoke(
          'gemini-proxy',
          body: contentParams,
        );

        if (response.status == 200) {
          final data = response.data;
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          return text ?? 'gemini_err_no_desc'.tr();
        } else {
          final errorData = response.data;
          final errorMsg = errorData['error'] ?? 'gemini_err_unknown'.tr();
          throw Exception('gemini_err_api'.tr(args: [errorMsg.toString()]));
        }
      } else {
        // Ücretsiz kullanıcı: Kendi ayarladığı API anahtarı kullanılarak HTTP atılır
        final apiKey = await _getApiKey();
        if (apiKey.isEmpty) {
          throw Exception('gemini_err_no_key'.tr());
        }

        final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(contentParams),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          return text ?? 'gemini_err_no_desc'.tr();
        } else {
          final errorData = jsonDecode(response.body);
          final errorMsg =
              errorData['error']?['message'] ?? 'gemini_err_unknown'.tr();
          throw Exception('gemini_err_api'.tr(args: [errorMsg.toString()]));
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('gemini_err_general'.tr(args: [e.toString()]));
    }
  }
}
