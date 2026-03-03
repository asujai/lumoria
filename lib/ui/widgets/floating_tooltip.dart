import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/services/gemini_service.dart';
import '../../core/database/database_helper.dart';

class FloatingTooltip extends StatefulWidget {
  final String selectedText;
  final String pdfName;
  final int pageNumber;
  final VoidCallback onClose;

  const FloatingTooltip({
    super.key,
    required this.selectedText,
    required this.pdfName,
    required this.pageNumber,
    required this.onClose,
  });

  @override
  State<FloatingTooltip> createState() => _FloatingTooltipState();
}

class _FloatingTooltipState extends State<FloatingTooltip> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? _explanation;
  bool _isLoading = true;
  String? _error;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _analyzeText();
  }

  Future<void> _analyzeText() async {
    try {
      final explanation =
          await _geminiService.explainContextualText(widget.selectedText);
      if (mounted) {
        setState(() {
          _explanation = explanation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToLibrary() async {
    if (_explanation == null) return;
    try {
      await _dbHelper.insertArtifact({
        'originalText': widget.selectedText,
        'aiExplanation': _explanation!,
        'date': DateTime.now().toIso8601String(),
        'pdfName': widget.pdfName,
        'pageNumber': widget.pageNumber,
      });
      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('tooltip_snack_saved'.tr()),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kayıt hatası: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A22), // Koyu özel arka plan
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          'tooltip_original'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary, // Vurgulu kelime
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.selectedText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary, // Vurgulu kelime
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isLoading && _explanation != null)
                    GestureDetector(
                      onTap: _isSaved ? null : _saveToLibrary,
                      child: Icon(
                        _isSaved
                            ? Icons.check_circle
                            : Icons.bookmark_add_outlined,
                        size: 20,
                        color: _isSaved
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70),
                    ),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                )
              else if (_explanation != null)
                Text(
                  _explanation!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
