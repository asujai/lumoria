import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:easy_localization/easy_localization.dart';
import '../config/env.dart';
import 'sync_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = Supabase.instance.client;

  Future<String?> loginWithEmail(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      SyncService().performSync();
      return null; // Başarılı
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return 'auth_err_wrong_cred'.tr();
      }
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'auth_err_unconfirmed'.tr();
      }
      return e.message;
    } catch (e) {
      return 'auth_err_login_fail'.tr(args: [e.toString()]);
    }
  }

  Future<String?> registerWithEmail(String email, String password) async {
    try {
      final response =
          await _supabase.auth.signUp(email: email, password: password);
      if (response.session == null) {
        return 'auth_succ_reg'.tr();
      }
      SyncService().performSync();
      return null; // Başarılı, giriş yapıldı
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        return 'auth_err_in_use'.tr();
      }
      return e.message;
    } catch (e) {
      return 'auth_err_reg_fail'.tr(args: [e.toString()]);
    }
  }

  Future<String?> loginWithGoogle() async {
    try {
      final webClientId = Env.googleWebClientId;
      if (webClientId.isEmpty) {
        return 'auth_err_google_no_id'.tr();
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return 'auth_err_google_cancel'.tr();
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        return 'auth_err_google_tokens'.tr();
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      SyncService().performSync();

      return null;
    } catch (e) {
      if (e.toString().contains('sign_in_canceled')) {
        return 'auth_err_google_cancel'.tr();
      }
      return 'auth_err_google_fail'.tr(args: [e.toString()]);
    }
  }

  Future<void> logout() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
      await _supabase.auth.signOut();
    } catch (_) {}
  }
}
