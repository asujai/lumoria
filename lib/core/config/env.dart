import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL', obfuscate: true)
  static final String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY', obfuscate: true)
  static final String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(
      varName: 'REVENUECAT_GOOGLE_KEY', obfuscate: true, defaultValue: '')
  static final String revenueCatGoogleKey = _Env.revenueCatGoogleKey;

  @EnviedField(
      varName: 'REVENUECAT_APPLE_KEY', obfuscate: true, defaultValue: '')
  static final String revenueCatAppleKey = _Env.revenueCatAppleKey;

  @EnviedField(
      varName: 'GOOGLE_WEB_CLIENT_ID', obfuscate: true, defaultValue: '')
  static final String googleWebClientId = _Env.googleWebClientId;
}
