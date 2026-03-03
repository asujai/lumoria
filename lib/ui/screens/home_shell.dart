import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'pdf_view_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

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
      body: isWideScreen
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (int index) {
                    setState(() => _currentIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.colorScheme.surface,
                  selectedIconTheme:
                      IconThemeData(color: theme.colorScheme.primary),
                  selectedLabelTextStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                  unselectedIconTheme:
                      IconThemeData(color: theme.colorScheme.onSurfaceVariant),
                  unselectedLabelTextStyle:
                      TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.auto_stories_outlined),
                      selectedIcon: const Icon(Icons.auto_stories),
                      label: Text('home_tab'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.bookmarks_outlined),
                      selectedIcon: const Icon(Icons.bookmarks),
                      label: Text('library_tab'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text('settings_tab'.tr()),
                    ),
                  ],
                ),
                VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: theme.colorScheme.surfaceContainerHighest),
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
                  _buildNavItem(
                    index: 0,
                    icon: Icons.auto_stories,
                    label: 'home_tab'.tr(),
                    theme: theme,
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.bookmarks,
                    label: 'library_tab'.tr(),
                    theme: theme,
                  ),
                  _buildNavItem(
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

  Widget _buildNavItem({
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
