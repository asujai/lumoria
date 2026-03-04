import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = Supabase.instance.client;

  Future<String?> loginWithEmail(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return null; // Başarılı
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return 'E-posta veya şifre hatalı.';
      }
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'E-posta adresiniz onaylanmamış. Lütfen doğrulayın veya Supabase ayarlarından kapatın.';
      }
      return e.message;
    } catch (e) {
      return 'Giriş yapılamadı: $e';
    }
  }

  Future<String?> registerWithEmail(String email, String password) async {
    try {
      final response =
          await _supabase.auth.signUp(email: email, password: password);
      if (response.session == null) {
        return 'Kayıt başarılı! Ancak Supabase ayarlarında e-posta onayı açık. Lütfen gelen kutunuzu kontrol edin veya Supabase ayarlarından Kapatın.';
      }
      return null; // Başarılı, giriş yapıldı
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        return 'Bu e-posta adresi zaten kullanılıyor.';
      }
      return e.message;
    } catch (e) {
      return 'Kayıt olunamadı: $e';
    }
  }

  Future<String?> loginWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(OAuthProvider.google);
      return null;
    } catch (e) {
      return 'Google girişi sırasında bir hata oluştu.';
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
  }
}
