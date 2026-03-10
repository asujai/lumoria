import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/services/settings_service.dart';
import 'core/services/purchase_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'ui/screens/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/secure_storage_service.dart';
import 'core/config/env.dart';
import 'ui/screens/auth_screen.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Custom Error Handler
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log('Flutter Error:',
        error: details.exception, stackTrace: details.stack);
    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
  };

  // Platform Dispatcher Error Handler
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Async Error:', error: error, stackTrace: stack);
    return true;
  };
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  await EasyLocalization.ensureInitialized();
  await SettingsService().loadSettings();
  await SecureStorageService().init();
  await PurchaseService().init();
  SyncService().init();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  FlutterNativeSplash.remove();

  // UI locale is only tr if TR is selected, else it acts as en
  final savedLang = SettingsService().language;
  final startLocale = Locale(savedLang);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('tr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      child: ContextPdfApp(showOnboarding: showOnboarding),
    ),
  );
}

class ContextPdfApp extends StatelessWidget {
  final bool showOnboarding;
  const ContextPdfApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, _) {
        final themeColor = SettingsService().themeColor;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'app_title'.tr(),
          localizationsDelegates: [
            ...context.localizationDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            SfGlobalLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: AppTheme.getLightTheme(themeColor),
          darkTheme: AppTheme.getDarkTheme(themeColor),
          themeMode:
              SettingsService().isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: showOnboarding
              ? const OnboardingScreen()
              : (!SettingsService().hasSeenAuth
                  ? const AuthScreen()
                  : const HomeShell()),
        );
      },
    );
  }
}
