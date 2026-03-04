import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/database/database_helper.dart';
import '../widgets/library_item_card.dart';
import 'pdf_view_screen.dart';
import 'quiz_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _allArtifacts = [];
  List<Map<String, dynamic>> _filteredArtifacts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _currentFilter = 'notes'; // 'notes', 'pdfs'
  bool _hideAllAnswers = false;

  @override
  void initState() {
    super.initState();
    _loadArtifacts();
    _dbHelper.artifactUpdateNotifier.addListener(_loadArtifacts);
  }

  @override
  void dispose() {
    _dbHelper.artifactUpdateNotifier.removeListener(_loadArtifacts);
    super.dispose();
  }

  Future<void> _loadArtifacts() async {
    final data = await _dbHelper.fetchAllArtifacts();
    if (mounted) {
      setState(() {
        _allArtifacts = data;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> current = List.from(_allArtifacts);

    if (_searchQuery.isNotEmpty) {
      current = current.where((item) {
        final original = (item['originalText'] as String).toLowerCase();
        final exp = (item['aiExplanation'] as String).toLowerCase();
        final q = _searchQuery.toLowerCase();
        return original.contains(q) || exp.contains(q);
      }).toList();
    }

    if (_currentFilter == 'notes') {
      current = current.where((item) => item['type'] != 'pdf').toList();
    } else if (_currentFilter == 'pdfs') {
      current = current.where((item) => item['type'] == 'pdf').toList();
    }

    setState(() {
      _filteredArtifacts = current;
    });
  }

  Future<void> _deleteArtifact(int id) async {
    await _dbHelper.deleteArtifact(id);
    _loadArtifacts();
  }

  void _showAddNoteDialog() {
    final originalTextController = TextEditingController();
    final explanationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('library_add_manual'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: originalTextController,
              decoration: InputDecoration(
                hintText: 'library_add_original'.tr(),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: explanationController,
              decoration: InputDecoration(
                hintText: 'library_add_desc'.tr(),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('library_btn_cancel'.tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final original = originalTextController.text.trim();
              final explanation = explanationController.text.trim();

              if (original.isNotEmpty && explanation.isNotEmpty) {
                await _dbHelper.insertArtifact({
                  'originalText': original,
                  'aiExplanation': explanation,
                  'date': DateTime.now().toIso8601String(),
                  'pdfName': 'pdf_manual_note'.tr(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadArtifacts();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
            ),
            child: Text('library_btn_save'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory(Map<String, dynamic> item) async {
    final history = await _dbHelper.getArtifactHistory(item['id'] as int);
    if (!mounted) return;

    final theme = Theme.of(context);
    final count = history.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              item['originalText'] as String,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'library_history_count'.tr(args: [count.toString()]),
              style: TextStyle(fontSize: 14, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final h = history[index];
                  final date = DateTime.parse(h['date'] as String);
                  final formattedDate =
                      '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.history,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h['pdfName'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                'library_history_page'
                                    .tr(args: [h['pageNumber'].toString()]),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        )),
                        Text(formattedDate,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('library_title'.tr()),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.psychology),
            label: Text('library_btn_repeat'.tr()),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuizScreen()),
              ).then((_) {
                // Refresh stats if needed, or _loadArtifacts
                _loadArtifacts();
              });
            },
          ),
          IconButton(
            icon:
                Icon(_hideAllAnswers ? Icons.visibility_off : Icons.visibility),
            tooltip: _hideAllAnswers
                ? 'library_btn_show_answers'.tr()
                : 'library_btn_hide_answers'.tr(),
            onPressed: () {
              setState(() {
                _hideAllAnswers = !_hideAllAnswers;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddNoteDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.surfaceContainerHighest),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (value) {
                                  _searchQuery = value;
                                  _applyFilters();
                                },
                                decoration: InputDecoration(
                                  hintText: 'library_search_hint'.tr(),
                                  hintStyle: TextStyle(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Filters Placeholder
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentFilter = 'notes';
                                _applyFilters();
                              });
                            },
                            child: _buildFilterChip(
                                theme,
                                'library_filter_all'.tr(),
                                _currentFilter == 'notes'),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentFilter = 'pdfs';
                                _applyFilters();
                              });
                            },
                            child: _buildFilterChip(
                                theme,
                                'library_filter_pdfs'.tr(),
                                _currentFilter == 'pdfs'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // List
                    Expanded(
                      child: _filteredArtifacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bookmark_border,
                                    size: 64,
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'library_empty'.tr(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _filteredArtifacts.length,
                              itemBuilder: (context, index) {
                                final item = _filteredArtifacts[index];
                                final isPdf = item['type'] == 'pdf';
                                final filePath = item['filePath'] as String?;

                                if (isPdf && filePath != null) {
                                  return _buildPdfLibraryCard(
                                      theme, item, filePath);
                                }

                                return LibraryItemCard(
                                  item: item,
                                  hideExplanation: _hideAllAnswers,
                                  onDelete: () =>
                                      _deleteArtifact(item['id'] as int),
                                  onTap: () => _showHistory(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPdfLibraryCard(
      ThemeData theme, Map<String, dynamic> item, String filePath) {
    final pdfName = item['pdfName'] as String;
    final date = item['date'] as String;
    final fileExists = File(filePath).existsSync();
    final formattedDate = date.length >= 10 ? date.substring(0, 10) : date;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: fileExists
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewScreen(initialFilePath: filePath),
                    ),
                  );
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    fileExists ? Icons.picture_as_pdf_outlined : Icons.link_off,
                    color: fileExists
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pdfName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileExists
                            ? formattedDate
                            : 'library_err_not_found'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: fileExists
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (fileExists)
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () => _deleteArtifact(item['id'] as int),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(ThemeData theme, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
