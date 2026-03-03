import 'dart:ui';
import 'package:flutter/material.dart';

class LibraryItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool hideExplanation;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const LibraryItemCard({
    super.key,
    required this.item,
    this.hideExplanation = false,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<LibraryItemCard> createState() => _LibraryItemCardState();
}

class _LibraryItemCardState extends State<LibraryItemCard> {
  late bool _localHide;

  @override
  void initState() {
    super.initState();
    _localHide = widget.hideExplanation;
  }

  @override
  void didUpdateWidget(covariant LibraryItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hideExplanation != widget.hideExplanation) {
      _localHide = widget.hideExplanation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.parse(widget.item['date'] as String);
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    // Create a title from the original text (up to 30 chars approx)
    final originalText = widget.item['originalText'] as String;
    final title = originalText.length > 40
        ? '${originalText.substring(0, 40)}...'
        : originalText;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _localHide ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _localHide = !_localHide;
                      });
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _localHide
                    ? () {
                        setState(() {
                          _localHide = false;
                        });
                      }
                    : null,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _localHide ? 5.0 : 0.0,
                    sigmaY: _localHide ? 5.0 : 0.0,
                  ),
                  child: Text(
                    widget.item['aiExplanation'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item['pdfName'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key(widget.item['id'].toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => widget.onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: card,
    );
  }
}
