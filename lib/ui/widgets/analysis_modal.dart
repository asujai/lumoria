import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/services/gemini_service.dart';
import '../../core/database/database_helper.dart';

class AnalysisModal extends StatefulWidget {
  final String selectedText;
  final String pdfName;
  final int pageNumber;

  const AnalysisModal({
    super.key,
    required this.selectedText,
    required this.pdfName,
    required this.pageNumber,
  });

  @override
  State<AnalysisModal> createState() => _AnalysisModalState();
}

class _AnalysisModalState extends State<AnalysisModal> {
  final GeminiService _geminiService = GeminiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String? _explanation;
  bool _isLoading = true;
  String? _error;
  bool _isSaved = false;

  List<Map<String, dynamic>> _folders = [];
  int? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _analyzeText();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await _dbHelper.fetchAllFolders();
    if (mounted) {
      setState(() {
        _folders = folders.where((f) => (f['category'] ?? 'notes') == 'notes').toList();
      });
    }
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
        'aiExplanation': _explanation,
        'date': DateTime.now().toIso8601String(),
        'pdfName': widget.pdfName,
        'pageNumber': widget.pageNumber,
        'folderId': _selectedFolderId,
      });

      if (mounted) {
        setState(() {
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kütüphaneye eklendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilirken hata oluştu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Original text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  width: 4,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Text(
              '"${widget.selectedText}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Analysis Result
          const Text(
            'Bağlamsal Analiz',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          else ...[
            Text(
              _explanation!,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            if (_folders.isNotEmpty && !_isSaved)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<int>(
                  value: _selectedFolderId,
                  decoration: InputDecoration(
                    labelText: 'Klasör Klasifikasyonu (Opsiyonel)',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Kategorize Edilmemiş'),
                    ),
                    ..._folders.map((f) => DropdownMenuItem<int>(
                          value: f['id'] as int,
                          child: Text(f['name'] as String),
                        ))
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaved ? null : _saveToLibrary,
                icon: Icon(_isSaved
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.bookmark),
                label: Text(_isSaved ? 'Kütüphanede' : 'Kütüphaneye Ekle'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: _isSaved ? Colors.green : theme.colorScheme.primary,
                  ),
                  foregroundColor:
                      _isSaved ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
