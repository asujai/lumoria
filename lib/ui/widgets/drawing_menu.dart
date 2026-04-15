import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'drawing_models.dart';

class DrawingMenu extends StatelessWidget {
  final ValueNotifier<DrawingSettings> settingsNotifier;
  final VoidCallback onClearStrokes;

  const DrawingMenu({
    super.key,
    required this.settingsNotifier,
    required this.onClearStrokes,
  });

  void _updateSettings(DrawingSettings newSettings) {
    settingsNotifier.value = newSettings;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrawingSettings>(
      valueListenable: settingsNotifier,
      builder: (context, settings, child) {
        if (!settings.isDrawingMode) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildToolButton(
                        context: context,
                        icon: Icons.edit,
                        isSelected:
                            !settings.isEraser && settings.opacity == 1.0,
                        onTap: () => _updateSettings(settings.copyWith(
                          isEraser: false,
                          opacity: 1.0,
                          strokeWidth: 3.0,
                        )),
                      ),
                      _buildToolButton(
                        context: context,
                        icon: Icons.brush,
                        isSelected:
                            !settings.isEraser && settings.opacity < 1.0,
                        onTap: () => _updateSettings(settings.copyWith(
                          isEraser: false,
                          opacity: 0.4,
                          strokeWidth: 12.0,
                        )),
                      ),
                      _buildToolButton(
                        context: context,
                        icon: Icons.cleaning_services,
                        isSelected: settings.isEraser,
                        onTap: () => _updateSettings(settings.copyWith(
                          isEraser: true,
                        )),
                      ),
                      Container(
                          width: 1, height: 24, color: theme.dividerColor),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        onPressed: onClearStrokes,
                        tooltip: 'clear_drawing'.tr(),
                      ),
                    ],
                  ),
                  if (!settings.isEraser) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildColorDot(Colors.red, settings),
                        const SizedBox(width: 12),
                        _buildColorDot(Colors.blue, settings),
                        const SizedBox(width: 12),
                        _buildColorDot(Colors.green, settings),
                        const SizedBox(width: 12),
                        _buildColorDot(Colors.yellow, settings),
                        const SizedBox(width: 12),
                        _buildColorDot(Colors.black, settings),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.strokeWidth,
                      min: 1.0,
                      max: 20.0,
                      activeColor: settings.color,
                      onChanged: (value) {
                        _updateSettings(settings.copyWith(strokeWidth: value));
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required BuildContext context,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, DrawingSettings settings) {
    final isSelected = settings.color.value == color.value;
    return GestureDetector(
      onTap: () => _updateSettings(settings.copyWith(color: color)),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }
}
