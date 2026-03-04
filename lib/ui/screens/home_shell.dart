import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'pdf_view_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import '../../core/services/settings_service.dart';
import '../widgets/lumoria_logo.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PdfViewScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWideScreen = MediaQuery.sizeOf(context).width > 600;

    Widget content = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isWideScreen
          ? Row(
              children: [
                _buildCustomSidebar(theme),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isWideScreen
          ? null
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.surfaceContainerHighest,
                    width: 1,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomNavItem(
                    index: 0,
                    icon: Icons.auto_stories,
                    label: 'home_tab'.tr(),
                    theme: theme,
                  ),
                  _buildBottomNavItem(
                    index: 1,
                    icon: Icons.library_books,
                    label: 'library_tab'.tr(),
                    theme: theme,
                  ),
                  _buildBottomNavItem(
                    index: 2,
                    icon: Icons.settings,
                    label: 'settings_tab'.tr(),
                    theme: theme,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomSidebar(ThemeData theme) {
    bool isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF101722).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.surfaceContainerHighest,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Log
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: LumoriaLogo(iconSize: 32, fontSize: 20),
          ),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSidebarItem(
                    0, Icons.home_rounded, 'home_tab'.tr(), theme),
                const SizedBox(height: 4),
                _buildSidebarItem(
                    1, Icons.library_books_rounded, 'library_tab'.tr(), theme),
                const SizedBox(height: 4),
                _buildSidebarItem(
                    2, Icons.settings_rounded, 'settings_tab'.tr(), theme),
              ],
            ),
          ),

          // User profile at bottom
          ListenableBuilder(
            listenable: SettingsService(),
            builder: (context, _) {
              final userName =
                  SettingsService().userName ?? 'home_lbl_username'.tr();
              final userTitle =
                  SettingsService().userTitle ?? 'home_lbl_title'.tr();

              return InkWell(
                onTap: () {
                  _showProfileDialog(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person,
                            color: theme.colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userTitle.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final nameController =
        TextEditingController(text: SettingsService().userName);
    final titleController =
        TextEditingController(text: SettingsService().userTitle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('home_dlg_profile'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'home_lbl_fullname'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'home_lbl_jobtitle'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('general_btn_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              SettingsService().setUserName(nameController.text.trim());
              SettingsService().setUserTitle(titleController.text.trim());
              Navigator.pop(context);
            },
            child: Text('general_btn_save'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      int index, IconData icon, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
