import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureAccessService {
  static final FeatureAccessService _instance =
      FeatureAccessService._internal();
  factory FeatureAccessService() => _instance;
  FeatureAccessService._internal();

  final _supabase = Supabase.instance.client;

  // Lütfen buraya kendi geliştirici Google Play e-postanızı / e-postalarınızı ekleyin.
  final List<String> _developerEmails = [
    'gokhanabdullah90@gmail.com',
    'developer@lumoria.ai',
    'abdullahgoksun14@gmail.com',
  ];

  bool isSyncFeatureEnabled() {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      return false;
    }

    // Geliştirici erişim kontrolü
    if (_developerEmails.contains(user.email)) {
      return true;
    }

    // İleride buraya abonelik sistemi eklenecek.
    // Örnek:
    // return PurchaseService().isPremium;

    return false;
  }
}
