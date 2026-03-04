import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/purchase_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _storageService = SecureStorageService();
  final _settingsService = SettingsService();
  bool _isLoading = false;
  bool _hasKey = false;
  bool _obscureKey = true;

  Map<String, int> _totalTime = {'activeTotal': 0, 'backgroundTotal': 0};
  List<Map<String, dynamic>> _pdfStats = [];

  final List<Color> _themeColors = [
    const Color(0xFF195DE6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingKey();
    _loadStatistics();
    DatabaseHelper.instance.artifactUpdateNotifier.addListener(_loadStatistics);
  }

  @override
  void dispose() {
    DatabaseHelper.instance.artifactUpdateNotifier
        .removeListener(_loadStatistics);
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final totalTime = await DatabaseHelper.instance.getTotalTime();
    final pdfStats = await DatabaseHelper.instance.getPdfStatistics();
    if (mounted) {
      setState(() {
        _totalTime = totalTime;
        _pdfStats = pdfStats;
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0 sn';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    List<String> parts = [];
    if (hours > 0) parts.add('$hours saat');
    if (minutes > 0) parts.add('$minutes dk');
    if (secs > 0) parts.add('$secs sn');

    return parts.join(' ');
  }

  Future<void> _clearStatistics() async {
    await DatabaseHelper.instance.clearStatistics();
    _loadStatistics();
  }

  Future<void> _checkExistingKey() async {
    final key = await _storageService.getApiKey();
    if (mounted) {
      setState(() {
        _hasKey = key != null && key.isNotEmpty;
        if (_hasKey) _apiKeyController.text = key!;
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);
    await _storageService.saveApiKey(key);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasKey = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_api_success'.tr())),
      );
    }
  }

  Future<void> _deleteKey() async {
    setState(() => _isLoading = true);
    await _storageService.deleteApiKey();
    _apiKeyController.clear();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasKey = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.query_builder, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('settings_title'.tr()),
          ],
        ),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: _settingsService,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // ── STATISTICS ──
                  _buildStatisticsCard(theme),
                  const SizedBox(height: 32),

                  if (_pdfStats.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionHeader('settings_pdf_times'.tr()),
                        TextButton.icon(
                          onPressed: _clearStatistics,
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.redAccent),
                          label: Text('settings_clear'.tr(),
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        )
                      ],
                    ),
                    ..._pdfStats.map((stat) => _buildPdfStatCard(stat, theme)),
                    const SizedBox(height: 32),
                  ],

                  // ── ACCOUNT & SYNC ──
                  _buildAccountCard(theme),
                  const SizedBox(height: 32),

                  // ── PREFERENCES ──
                  _sectionHeader('settings_pref_header'.tr()),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: theme.colorScheme.surfaceContainerHighest),
                    ),
                    child: Column(
                      children: [
                        _settingsTile(
                          theme: theme,
                          icon: Icons.dark_mode_outlined,
                          title: 'settings_dark_mode'.tr(),
                          subtitle: 'settings_dark_mode_sub'.tr(),
                          trailing: Switch.adaptive(
                            value: _settingsService.isDarkMode,
                            onChanged: (v) => _settingsService.setDarkMode(v),
                            activeTrackColor: theme.colorScheme.primary,
                          ),
                        ),
                        Divider(
                            height: 1,
                            color: theme.colorScheme.surfaceContainerHighest),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.palette_outlined,
                                  size: 24,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'settings_theme_color'.tr(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: _themeColors.map((c) {
                                  final isSelected =
                                      _settingsService.themeColor.toARGB32() ==
                                          c.toARGB32();
                                  return GestureDetector(
                                    onTap: () =>
                                        _settingsService.setThemeColor(c),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                width: 2)
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              )
                            ],
                          ),
                        ),
                        Divider(
                            height: 1,
                            color: theme.colorScheme.surfaceContainerHighest),
                        _settingsTile(
                          theme: theme,
                          icon: Icons.language,
                          title: 'settings_doc_lang'.tr(),
                          subtitle: 'settings_doc_lang_sub'.tr(),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _settingsService.language,
                              isDense: true,
                              icon: Icon(Icons.unfold_more,
                                  color: theme.colorScheme.onSurfaceVariant),
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem(
                                    value: 'tr', child: Text('TR')),
                                DropdownMenuItem(
                                    value: 'en', child: Text('EN')),
                                DropdownMenuItem(
                                    value: 'de', child: Text('DE')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  // avoid switching if DE because no JSON file
                                  if (v == 'de') return;
                                  _settingsService.setLanguage(v);
                                  context.setLocale(Locale(v));
                                }
                              },
                            ),
                          ),
                        ),
                        Divider(
                            height: 1,
                            color: theme.colorScheme.surfaceContainerHighest),
                        _settingsTile(
                          theme: theme,
                          icon: Icons.school_outlined,
                          title: 'settings_field_of_study'.tr(),
                          subtitle: 'settings_field_of_study_sub'.tr(),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _settingsService.fieldOfStudy,
                              isDense: true,
                              icon: Icon(Icons.unfold_more,
                                  color: theme.colorScheme.onSurfaceVariant),
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500),
                              items: [
                                DropdownMenuItem(
                                    value: 'Sağlık',
                                    child: Text('field_health'.tr())),
                                DropdownMenuItem(
                                    value: 'Hukuk',
                                    child: Text('field_law'.tr())),
                                DropdownMenuItem(
                                    value: 'Edebiyat',
                                    child: Text('field_literature'.tr())),
                                DropdownMenuItem(
                                    value: 'Yabancı Dil',
                                    child: Text('field_foreign_lang'.tr())),
                                DropdownMenuItem(
                                    value: 'Genel',
                                    child: Text('field_general'.tr())),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _settingsService.setFieldOfStudy(v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── API CONFIGURATION ──
                  _sectionHeader('settings_api_config'.tr()),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: theme.colorScheme.surfaceContainerHighest),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini API Key',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'settings_api_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureKey,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'settings_api_hint'.tr(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: theme.colorScheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _hasKey ? _deleteKey : null,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(
                                      color: _hasKey
                                          ? Colors.redAccent
                                          : theme.colorScheme
                                              .surfaceContainerHighest),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'settings_api_btn_del'.tr(),
                                  style: TextStyle(
                                      color: _hasKey
                                          ? Colors.redAccent
                                          : theme.colorScheme
                                              .surfaceContainerHighest),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveKey,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.surface,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Text(
                                        _hasKey
                                            ? 'settings_api_btn_update'.tr()
                                            : 'settings_api_btn_connect'.tr(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Aktif Süre',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<int>(
                      valueListenable: SettingsService.activeSessionTime,
                      builder: (context, activeTime, _) {
                        return Text(
                          _formatDuration(
                              _totalTime['activeTotal']! + activeTime),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Arka Plan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(_totalTime['backgroundTotal']!),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfStatCard(Map<String, dynamic> stat, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stat['pdfName'] as String,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Aktif: ${_formatDuration(stat['activeSeconds'] as int)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Arka: ${_formatDuration(stat['backgroundSeconds'] as int)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Removed profile card as it is replaced with statistics.

  Widget _settingsTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ]
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) async {
    final theme = Theme.of(context);
    bool isPurchasing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Premium\'a Yükselt',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Çoklu cihaz senkronizasyonu ve gelişmiş istatistik özelliklerinin kilidini açın.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isPurchasing)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Monthly Subscription Option
                      _buildPurchaseOption(
                        title: 'Aylık Abonelik',
                        price: '\$1.00 / ay',
                        description: 'İstediğiniz zaman iptal edebilirsiniz.',
                        icon: Icons.calendar_month,
                        theme: theme,
                        onTap: () async {
                          setModalState(() => isPurchasing = true);
                          final package =
                              PurchaseService().offerings?.current?.monthly;
                          if (package != null) {
                            final success = await PurchaseService()
                                .purchasePackage(package);
                            if (ctx.mounted) {
                              setModalState(() => isPurchasing = false);
                              if (success) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Aylık premium hesabınız aktif edildi!')),
                                );
                                setState(() {});
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Satın alma işlemi tamamlanamadı veya iptal edildi.')),
                                );
                              }
                            }
                          } else {
                            if (ctx.mounted) {
                              setModalState(() => isPurchasing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Aylık paket şu anda kullanılamıyor. (RevenueCat bağlantısını kontrol edin)')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Lifetime Option
                      _buildPurchaseOption(
                        title: 'Ömür Boyu Erişim',
                        price: '\$5.00',
                        description:
                            'Tek sefere mahsus ödeme, sınırsız kullanım.',
                        icon: Icons.all_inclusive,
                        isHighlight: true,
                        theme: theme,
                        onTap: () async {
                          setModalState(() => isPurchasing = true);
                          final package =
                              PurchaseService().offerings?.current?.lifetime;
                          if (package != null) {
                            final success = await PurchaseService()
                                .purchasePackage(package);
                            if (ctx.mounted) {
                              setModalState(() => isPurchasing = false);
                              if (success) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Ömür boyu premium hesabınız aktif edildi!')),
                                );
                                setState(() {});
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Satın alma işlemi tamamlanamadı veya iptal edildi.')),
                                );
                              }
                            }
                          } else {
                            if (ctx.mounted) {
                              setModalState(() => isPurchasing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Ömür boyu paket şu anda kullanılamıyor. (RevenueCat bağlantısını kontrol edin)')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          setModalState(() => isPurchasing = true);
                          final restored =
                              await PurchaseService().restorePurchases();
                          setModalState(() => isPurchasing = false);
                          if (ctx.mounted) {
                            if (restored) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Satın alımlarınız geri yüklendi!')),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Geri yüklenecek aktif abonelik bulunamadı.')),
                              );
                            }
                          }
                        },
                        child: const Text('Satın Alımları Geri Yükle'),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPurchaseOption({
    required String title,
    required String price,
    required String description,
    required IconData icon,
    required ThemeData theme,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isHighlight ? 2 : 1,
          ),
          color: isHighlight
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighlight
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isHighlight
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(price,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(ThemeData theme) {
    final isLoggedIn = _settingsService.isLoggedIn;
    final isPremium = _settingsService.isPremium;
    final userEmail = _settingsService.userEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('HESAP VE SENKRONİZASYON'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: theme.colorScheme.surfaceContainerHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      isLoggedIn ? Icons.person : Icons.person_outline,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoggedIn
                              ? (userEmail ?? 'Bilinmeyen Kullanıcı')
                              : 'Ziyaretçi (Çevrimdışı)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLoggedIn
                                    ? (isPremium
                                        ? Colors.amber.shade100
                                        : Colors.blue.shade100)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isLoggedIn
                                    ? (isPremium
                                        ? 'Premium Aktif'
                                        : 'Standart Plan')
                                    : 'Ücretsiz',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isLoggedIn
                                      ? (isPremium
                                          ? Colors.amber.shade900
                                          : Colors.blue.shade900)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true)
                          .pushReplacement(
                        MaterialPageRoute(
                            builder: (context) => const AuthScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Giriş Yap / Üye Ol'),
                  ),
                )
              else
                Row(
                  children: [
                    if (!isPremium)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showUpgradeDialog(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade700,
                            side: BorderSide(color: Colors.amber.shade700),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Hesabı Yükselt'),
                        ),
                      ),
                    if (!isPremium) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isPremium
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Senkronizasyon simüle ediliyor...')),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Premium üyeler için bulut senkronizasyonu.')),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPremium
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: isPremium
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.cloud_sync, size: 18),
                        label: const Text('Senkronize Et'),
                      ),
                    ),
                  ],
                ),
              if (isLoggedIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      await AuthService().logout();
                      await _settingsService.setLoggedIn(false);
                      await _settingsService.setHasSeenAuth(false);
                      if (mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => const AuthScreen()),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error),
                    child: const Text('Çıkış Yap'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
