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
  List<Map<String, dynamic>> _folders = [];
  int? _selectedFolderId;

  bool _isLoading = true;
  String _searchQuery = '';
  String _currentFilter = 'notes'; // 'notes', 'pdfs', 'quotes'
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
    final quotesData = await _dbHelper.fetchAllQuotes();
    final folderData = await _dbHelper.fetchAllFolders();

    // Convert quotes to a format similar to artifacts for unified filtering
    final formattedQuotes = quotesData.map((q) {
      return {
        'id': q['id'],
        'originalText': q['quotedText'],
        'aiExplanation': 'Sayfa: ${q['pageNumber']}',
        'date': q['date'],
        'pdfName': q['pdfName'],
        'type': 'quote',
        'folderId': q['folderId'],
      };
    }).toList();

    if (mounted) {
      setState(() {
        _allArtifacts = [...data, ...formattedQuotes];
        _folders = folderData;
        _allArtifacts.sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String));
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
      current = current
          .where((item) => item['type'] != 'pdf' && item['type'] != 'quote')
          .toList();
    } else if (_currentFilter == 'pdfs') {
      current = current.where((item) => item['type'] == 'pdf').toList();
    } else if (_currentFilter == 'quotes') {
      current = current.where((item) => item['type'] == 'quote').toList();
    }

    if (_selectedFolderId != null) {
      current = current.where((item) => item['folderId'] == _selectedFolderId).toList();
    } else {
      // Opsiyonel: selectedFolderId null ise, tümünü göster veya SADECE klasörsüz olanları göster
      // Biz klasörsüz olanları "Tümü" olarak göstermeyi tercih edebiliriz. Tümünü gösterelim.
    }

    setState(() {
      _filteredArtifacts = current;
    });
  }

  Future<void> _deleteArtifact(int id, {bool isQuote = false}) async {
    if (isQuote) {
      await _dbHelper.deleteQuote(id);
    } else {
      await _dbHelper.deleteArtifact(id);
    }
    _loadArtifacts();
  }

  void _showAddNoteDialog() {
    final originalTextController = TextEditingController();
    final explanationController = TextEditingController();
    int? selectedFolderId = _selectedFolderId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
              const SizedBox(height: 12),
              if (_folders.where((f) => (f['category'] ?? 'notes') == 'notes').isNotEmpty)
                DropdownButtonFormField<int>(
                  value: selectedFolderId,
                  decoration: InputDecoration(
                    labelText: 'Klasör (Opsiyonel)',
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Klasör Yok'),
                    ),
                    ..._folders.where((f) => (f['category'] ?? 'notes') == 'notes').map((f) => DropdownMenuItem<int>(
                          value: f['id'] as int,
                          child: Text(f['name'] as String),
                        ))
                  ],
                  onChanged: (val) => setDialogState(() => selectedFolderId = val),
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
                    'folderId': selectedFolderId,
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
      ),
    );
  }

  void _showAddFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Klasör'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Klasör adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _dbHelper.insertFolder(controller.text.trim(), _currentFilter);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadArtifacts();
              }
            },
            child: const Text('Oluştur'),
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
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentFilter = 'quotes';
                                _applyFilters();
                              });
                            },
                            child: _buildFilterChip(
                                theme,
                                'library_filter_quotes'.tr(),
                                _currentFilter == 'quotes'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Folders Horizontal List
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFolderChip(theme, null, 'Tümü', _selectedFolderId == null),
                          ..._folders
                              .where((f) => (f['category'] ?? 'notes') == _currentFilter)
                              .map((f) => _buildFolderChip(theme, f['id'] as int, f['name'] as String, _selectedFolderId == f['id'])),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 5, bottom: 5),
                            child: ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text('Klasör Ekle'),
                              onPressed: _showAddFolderDialog,
                              backgroundColor: theme.colorScheme.surface,
                              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                            ),
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
                                final isQuote = item['type'] == 'quote';

                                if (isPdf) {
                                  final filePath = item['filePath'] as String?;
                                  if (filePath != null) {
                                    return _buildPdfLibraryCard(
                                        theme, item, filePath);
                                  }
                                }

                                if (isQuote) {
                                  return _buildQuoteCard(theme, item);
                                }

                                return LibraryItemCard(
                                  item: item,
                                  onDelete: () =>
                                      _deleteArtifact(item['id'] as int),
                                  onTap: () => _showHistory(item),
                                  onLongPress: () =>
                                      _showMoveToFolderDialog(item['id'] as int, isQuote: false),
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

  Widget _buildQuoteCard(ThemeData theme, Map<String, dynamic> item) {
    final originalText = item['originalText'] as String;
    final pdfName = item['pdfName'] as String;
    final aiExplanation = item['aiExplanation'] as String; // e.g. "Sayfa: 1"
    final date = item['date'] as String;
    final formattedDate = date.length >= 10 ? date.substring(0, 10) : date;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _showMoveToFolderDialog(item['id'] as int, isQuote: true),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote,
                      color: theme.colorScheme.tertiary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      originalText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () =>
                        _deleteArtifact(item['id'] as int, isQuote: true),
                    alignment: Alignment.topRight,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                  color: theme.colorScheme.surfaceContainerHighest, height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pdfName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    aiExplanation,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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

  Widget _buildFolderChip(ThemeData theme, int? id, String name, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFolderId = id;
            _applyFilters();
          });
        },
        onLongPress: id != null ? () {
          // Delete folder option
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Klasörü Sil'),
              content: const Text('Bu klasörü silmek istediğinize emin misiniz? İçindeki notlar silinmez, sadece klasör bağlantıları kaldırılır.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _dbHelper.deleteFolder(id);
                    if (_selectedFolderId == id) {
                      _selectedFolderId = null;
                    }
                    _loadArtifacts();
                  }, 
                  child: const Text('Sil', style: TextStyle(color: Colors.red))
                ),
              ]
            )
          );
        } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.tertiary : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.tertiary : theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Row(
            children: [
              Icon(
                id == null ? Icons.all_inclusive : Icons.folder_outlined,
                size: 16,
                color: isSelected ? theme.colorScheme.onTertiary : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? theme.colorScheme.onTertiary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(int itemId, {required bool isQuote}) {
    final availableFolders = _folders.where((f) => (f['category'] ?? 'notes') == _currentFilter).toList();
    
    if (availableFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bu kategoride klasör bulunmuyor.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Klasöre Taşı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_off),
                title: const Text('Klasörden Çıkar (Hiçbiri)'),
                onTap: () async {
                  if (isQuote) {
                    await _dbHelper.updateQuoteFolder(itemId, null);
                  } else {
                    await _dbHelper.updateArtifactFolder(itemId, null);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadArtifacts();
                  }
                },
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableFolders.length,
                  itemBuilder: (context, index) {
                    final folder = availableFolders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder['name']),
                      onTap: () async {
                        if (isQuote) {
                          await _dbHelper.updateQuoteFolder(itemId, folder['id']);
                        } else {
                          await _dbHelper.updateArtifactFolder(itemId, folder['id']);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadArtifacts();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
