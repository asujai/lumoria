import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'settings_service.dart';
import '../config/env.dart';

class PurchaseService extends ChangeNotifier {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  Future<void> init() async {
    // Platform control for RevenueCat. Not officially supported on Windows via purchases_flutter.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      await Purchases.setLogLevel(LogLevel.debug);

      late PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(Env.revenueCatGoogleKey);
      } else if (Platform.isIOS || Platform.isMacOS) {
        configuration = PurchasesConfiguration(Env.revenueCatAppleKey);
      }

      await Purchases.configure(configuration);
      _setupCustomerInfoListener();
      await fetchOfferings();
    }

    // We fall back to SettingsService in case revenuecat isn't loaded (e.g. on Windows desktop)
    _isPremium = SettingsService().isPremium;
  }

  void _setupCustomerInfoListener() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updatePremiumStatus(customerInfo);
    });
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) async {
    // Entitlement configuration name. Change 'premium' to your revenuecat entitlement identifier
    final isPremiumNow =
        customerInfo.entitlements.all['premium']?.isActive ?? false;
    if (_isPremium != isPremiumNow) {
      _isPremium = isPremiumNow;
      await SettingsService().setPremium(isPremiumNow);
      notifyListeners();
    }
  }

  Future<void> fetchOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      // ignore: deprecated_member_use
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      _updatePremiumStatus(customerInfo);
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }
}
