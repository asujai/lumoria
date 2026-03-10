import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/secure_storage_service.dart';
import '../widgets/lumoria_logo.dart';

class ApiKeySetupScreen extends StatefulWidget {
  const ApiKeySetupScreen({super.key});

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;

  List<Map<String, String>> get _steps => [
        {
          'image': 'assets/images/api_guide/1.png',
          'text': "api_guide_step1_text".tr(),
          'link': 'https://aistudio.google.com/app/apikey',
        },
        {
          'image': 'assets/images/api_guide/2.png',
          'text': "api_guide_step2_text".tr(),
        },
        {
          'image': 'assets/images/api_guide/3.png',
          'text': "api_guide_step3_text".tr(),
        },
        {
          'image': 'assets/images/api_guide/4.png',
          'text': "api_guide_step4_text".tr(),
          'text2': "api_guide_step4_text2".tr(),
        },
      ];

  Future<void> _launchGeminiStudio() async {
    final url = Uri.parse('https://aistudio.google.com/app/apikey');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('api_guide_err_open_url'.tr(args: [url.toString()]))),
        );
      }
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);
    await SecureStorageService().saveApiKey(key);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Center(
                    child: LumoriaLogo(iconSize: 48, fontSize: 24),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'api_guide_title'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'api_guide_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA Button
                  ElevatedButton.icon(
                    onPressed: _launchGeminiStudio,
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: Text(
                      'api_guide_btn_gotostudio'.tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4-Step Guide
                  ...List.generate(_steps.length, (i) {
                    final step = _steps[i];
                    return _buildStepCard(
                      theme: theme,
                      isDark: isDark,
                      stepNumber: i + 1,
                      imagePath: step['image']!,
                      description: step['text']!,
                      text2: step['text2'],
                      link: step['link'],
                    );
                  }),

                  const SizedBox(height: 8),

                  // Input Field
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'api_guide_input_label'.tr(),
                      hintText: 'AIzaSy...',
                      prefixIcon: Icon(Icons.vpn_key_rounded,
                          color: theme.colorScheme.primary),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  FilledButton(
                    onPressed: _isLoading ? null : _saveKey,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            'api_guide_btn_save'.tr(),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required ThemeData theme,
    required bool isDark,
    required int stepNumber,
    required String imagePath,
    required String description,
    String? text2,
    String? link,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    stepNumber.toString(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (link != null) ...[
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final u = Uri.parse(link);
                                try {
                                  await launchUrl(u,
                                      mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  debugPrint('Could not launch \$u');
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4.0, horizontal: 2.0),
                                child: Text(
                                  link,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (text2 != null) ...[
                          if (link == null)
                            const SizedBox(height: 8)
                          else
                            const SizedBox(height: 12),
                          Text(
                            text2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
