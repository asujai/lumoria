import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../widgets/floating_tooltip.dart';
import '../widgets/drawing_menu.dart';
import '../widgets/drawing_overlay.dart';
import '../widgets/drawing_models.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/settings_service.dart';
import '../widgets/lumoria_logo.dart';

class PdfViewScreen extends StatefulWidget {
  /// Kütüphaneden açılırken mevcut bir dosya yolu verilebilir.
  final String? initialFilePath;

  const PdfViewScreen({super.key, this.initialFilePath});

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final UndoHistoryController _undoController = UndoHistoryController();

  double _currentZoom = 1.0;

  File? _selectedPdfFile;
  String _pdfName = 'pdf_unknown'.tr();
  String? _tooltipText;
  Rect? _tooltipRect;
  bool _isSavingToLibrary = false;
  bool _isLibraryPdf = false; // true ise otomatik kayıt aktif
  Timer? _autoSaveTimer;

  // Search attributes
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Timer attributes
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;
  int _unsavedSeconds = 0; // Active time
  int _totalUnsavedSeconds = 0; // Background total time
  bool _isTimerRunning = false;

  // Recent PDFs for home screen view
  List<Map<String, dynamic>> _recentPdfs = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentPdfs();
    if (widget.initialFilePath != null) {
      final file = File(widget.initialFilePath!);
      if (file.existsSync()) {
        _selectedPdfFile = file;
        _pdfName = file.uri.pathSegments.last;
        // saved_pdfs dizinindeyse kütüphane PDF'i — oto-kayıt aktif
        _isLibraryPdf = widget.initialFilePath!.contains('saved_pdfs');
        _startMasterTimer();
        _loadDrawingStrokes();
      }
    }
  }

  Future<void> _loadRecentPdfs() async {
    final data = await DatabaseHelper.instance.fetchAllArtifacts();
    if (mounted) {
      setState(() {
        _recentPdfs = data.where((item) => item['type'] == 'pdf').toList()
          ..sort(
              (a, b) => (b['date'] as String).compareTo(a['date'] as String));
        if (_recentPdfs.length > 5) {
          _recentPdfs = _recentPdfs.sublist(0, 5);
        }
        _isLoadingRecent = false;
      });
    }
  }

  void _startMasterTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _selectedPdfFile != null) {
        bool shouldSave = false;

        _totalUnsavedSeconds++;
        if (_isTimerRunning) {
          _elapsedSeconds++;
          _unsavedSeconds++;
          SettingsService.activeSessionTime.value = _elapsedSeconds;
        }

        if (_unsavedSeconds >= 5 || _totalUnsavedSeconds >= 5) {
          shouldSave = true;
        }

        if (shouldSave) {
          DatabaseHelper.instance
              .savePdfSession(_pdfName, _unsavedSeconds, _totalUnsavedSeconds);
          _unsavedSeconds = 0;
          _totalUnsavedSeconds = 0;
        }
      }
    });
  }

  void _startTimer() {
    if (_isTimerRunning) return;
    setState(() => _isTimerRunning = true);
  }

  void _pauseTimer() {
    setState(() => _isTimerRunning = false);
  }

  void _saveSession() {
    if ((_unsavedSeconds > 0 || _totalUnsavedSeconds > 0) &&
        _selectedPdfFile != null) {
      DatabaseHelper.instance
          .savePdfSession(_pdfName, _unsavedSeconds, _totalUnsavedSeconds);
      _unsavedSeconds = 0;
      _totalUnsavedSeconds = 0;
      SettingsService.activeSessionTime.value = 0;
    }
  }

  void _setZoom(double newZoom) {
    setState(() {
      _currentZoom = newZoom.clamp(0.1, 5.0);
      if (_currentZoom >= 1.0) {
        _pdfViewerController.zoomLevel = _currentZoom;
      } else {
        if (_pdfViewerController.zoomLevel != 1.0) {
          _pdfViewerController.zoomLevel = 1.0;
        }
      }
    });
  }

  void _zoomIn() {
    double baseZoom =
        _currentZoom >= 1.0 ? _pdfViewerController.zoomLevel : _currentZoom;
    _setZoom(baseZoom + 0.1);
  }

  void _zoomOut() {
    double baseZoom =
        _currentZoom >= 1.0 ? _pdfViewerController.zoomLevel : _currentZoom;
    _setZoom(baseZoom - 0.1);
  }

  Future<void> _pickPdf() async {
    _hideTooltip();
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _saveSession();
      if (mounted) {
        setState(() {
          _selectedPdfFile = File(result.files.single.path!);
          _pdfName = result.files.single.name;
          _isLibraryPdf = false; // harici dosya — oto-kayıt kapalı
          _selectedTextNotifier.value = null;
          _selectedTextRectNotifier.value = null;
          _isSearching = false;
          _searchController.clear();
          _searchResult.clear();
          _elapsedSeconds = 0;
          _unsavedSeconds = 0;
          _totalUnsavedSeconds = 0;
          _isTimerRunning = false;
          SettingsService.activeSessionTime.value = 0;
          _startMasterTimer();
        });
        _loadDrawingStrokes();
      }
    }
  }

  void _closePdf() {
    _saveDrawingStrokes();
    _saveSession();
    _sessionTimer?.cancel();
    _hideTooltip();
    if (mounted) {
      setState(() {
        _selectedPdfFile = null;
        _pdfName = 'pdf_unknown'.tr();
        _isLibraryPdf = false;
        _selectedTextNotifier.value = null;
        _selectedTextRectNotifier.value = null;
        _isSearching = false;
        _searchController.clear();
        _searchResult.clear();
        _elapsedSeconds = 0;
        _unsavedSeconds = 0;
        _totalUnsavedSeconds = 0;
        _isTimerRunning = false;
        SettingsService.activeSessionTime.value = 0;
      });
      _loadRecentPdfs();
    }
  }

  /// Annotation değişiminde debounced otomatik kayıt (yalnızca kütüphane PDF'leri).
  void _scheduleAutoSave() {
    if (!_isLibraryPdf || _selectedPdfFile == null) return;

    // Çizim modundayken PDF dosyasını serileştirmek (saveDocument)
    // ana thread'i bloke ederek "lag/kasma" sorunlarına (Event Flooding) yol açar.
    // Kullanıcı çizim modundan çıkana kadar oto-kayıtları duraklatıyoruz.
    if (_drawingSettingsNotifier.value.isDrawingMode) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () async {
      await _autoSaveAnnotations();
    });
  }

  /// PDF'yi annotation'larıyla birlikte dosyaya yazar.
  Future<void> _autoSaveAnnotations() async {
    if (_selectedPdfFile == null) return;
    try {
      final List<int> bytes = await _pdfViewerController.saveDocument();
      await _selectedPdfFile!.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('AutoSave error: $e');
    }
  }

  /// Çizim stroke'larını SQLite'a JSON olarak kaydet
  Future<void> _saveDrawingStrokes() async {
    if (_selectedPdfFile == null) return;
    final strokes = _drawingStrokesNotifier.value;
    if (strokes.isEmpty) {
      // Boşsa kaydı sil
      await DatabaseHelper.instance
          .deleteDrawingStrokes(_selectedPdfFile!.path);
      return;
    }
    final json = DrawingStroke.encodeList(strokes);
    await DatabaseHelper.instance
        .saveDrawingStrokes(_selectedPdfFile!.path, json);
  }

  /// SQLite'tan çizim stroke'larını yükle
  Future<void> _loadDrawingStrokes() async {
    if (_selectedPdfFile == null) return;
    final json = await DatabaseHelper.instance
        .loadDrawingStrokes(_selectedPdfFile!.path);
    if (json != null && json.isNotEmpty) {
      try {
        final strokes = DrawingStroke.decodeList(json);
        _drawingStrokesNotifier.value = strokes;
      } catch (e) {
        debugPrint('Çizim yükleme hatası: $e');
      }
    } else {
      _drawingStrokesNotifier.value = [];
    }
  }

  /// PDF dosyasını uygulama belgeler klasörüne kopyalar ve kütüphaneye kaydeder.
  Future<void> _savePdfToLibrary() async {
    if (_selectedPdfFile == null) return;
    setState(() => _isSavingToLibrary = true);

    try {
      // Uygulama belgeler dizini
      final docsDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${docsDir.path}/saved_pdfs');
      if (!pdfDir.existsSync()) {
        pdfDir.createSync(recursive: true);
      }

      final destPath = '${pdfDir.path}/$_pdfName';
      final destFile = File(destPath);

      // Aynı dosya yoksa kopyala
      if (!destFile.existsSync()) {
        await _selectedPdfFile!.copy(destPath);
      }

      // Kütüphaneye 'pdf' tipiyle kaydet (tekrar eklemeyi önle)
      final existing = await DatabaseHelper.instance.fetchAllArtifacts();
      final alreadySaved = existing.any(
        (e) => e['type'] == 'pdf' && e['filePath'] == destPath,
      );

      if (!alreadySaved) {
        await DatabaseHelper.instance.insertArtifact({
          'originalText': _pdfName,
          'aiExplanation': 'PDF dosyası',
          'date': DateTime.now().toIso8601String(),
          'pdfName': _pdfName,
          'type': 'pdf',
          'filePath': destPath,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pdf_saved_to_library'.tr()),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pdf_save_error'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingToLibrary = false);
    }
  }

  void _showTooltip(String text, Rect globalRect) {
    if (mounted) {
      setState(() {
        _tooltipText = text;
        _tooltipRect = globalRect;
      });
    }
  }

  void _hideTooltip() {
    if (_tooltipText != null && mounted) {
      setState(() {
        _tooltipText = null;
        _tooltipRect = null;
      });
    }
  }

  Widget _buildInlineTooltip() {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final appBarHeight = kToolbarHeight;
    final topOffset = padding.top + appBarHeight;

    double tooltipWidth = size.width > 352 ? 320 : size.width - 32;
    double tooltipHeight = 310;

    // Convert global coordinates to local body coordinates
    double localTargetTop = _tooltipRect!.top - topOffset;
    double localTargetBottom = _tooltipRect!.bottom - topOffset;
    double localTargetLeft = _tooltipRect!.left;

    double left = localTargetLeft;
    if (left + tooltipWidth > size.width - 16) {
      left = size.width - tooltipWidth - 16;
    }
    if (left < 16) left = 16;

    double bodyHeight = size.height - topOffset;
    
    double top = localTargetTop - tooltipHeight - 10;
    
    if (top < 16) {
      top = localTargetBottom + 10;
    }
    
    if (top + tooltipHeight > bodyHeight - 16 && top >= localTargetBottom) {
      top = bodyHeight - tooltipHeight - 16;
    }
    
    if (top < 16) top = 16;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _hideTooltip,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: top,
          left: left,
          child: FloatingTooltip(
            selectedText: _tooltipText!,
            pdfName: _pdfName,
            pageNumber: _currentPageNotifier.value,
            onClose: _hideTooltip,
          ),
        ),
      ],
    );
  }

  final ValueNotifier<String?> _selectedTextNotifier = ValueNotifier(null);
  final ValueNotifier<Rect?> _selectedTextRectNotifier = ValueNotifier(null);
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(1);
  final ValueNotifier<int> _totalPagesNotifier = ValueNotifier(0);

  // Drawing state
  final ValueNotifier<DrawingSettings> _drawingSettingsNotifier =
      ValueNotifier(const DrawingSettings());
  final ValueNotifier<List<DrawingStroke>> _drawingStrokesNotifier =
      ValueNotifier([]);

  // Position for draggable timer
  Offset _timerPosition = const Offset(20, 100);

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_isTimerRunning) {
      _saveSession();
    }
    _hideTooltip();
    _undoController.dispose();
    _pdfViewerController.dispose();
    _selectedTextNotifier.dispose();
    _selectedTextRectNotifier.dispose();
    _currentPageNotifier.dispose();
    _totalPagesNotifier.dispose();
    _drawingSettingsNotifier.dispose();
    _drawingStrokesNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildPdfViewer() {
    Widget viewer = Transform.scale(
        scale: _currentZoom < 1.0 ? _currentZoom : 1.0,
        alignment: Alignment.center,
        child: SfPdfViewer.file(
          _selectedPdfFile!,
          controller: _pdfViewerController,
          undoController: _undoController,
          canShowScrollHead: false,
          enableDoubleTapZooming: false,
          maxZoomLevel: 5.0,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            _hideTooltip();
            _totalPagesNotifier.value = details.document.pages.count;
          },
          onPageChanged: (PdfPageChangedDetails details) {
            _currentPageNotifier.value = details.newPageNumber;
          },
          onAnnotationAdded: (Annotation annotation) {
            _scheduleAutoSave();
            setState(() {}); // undo butonunu güncelle
          },
          onAnnotationRemoved: (Annotation annotation) {
            _scheduleAutoSave();
            setState(() {});
          },
          onAnnotationEdited: (Annotation annotation) {
            _scheduleAutoSave();
          },
          onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
            if (details.selectedText != null &&
                details.selectedText!.trim().isNotEmpty) {
              _selectedTextNotifier.value = details.selectedText!.trim();
              _selectedTextRectNotifier.value = details.globalSelectedRegion;
            } else {
              _selectedTextNotifier.value = null;
              _selectedTextRectNotifier.value = null;
            }
          },
        ));

    // Add drawing overlay on top of standard viewer, but before Dark Mode filter
    // so the drawn colors are also affected by the dark mode filter appropriately
    viewer = Stack(
      children: [
        viewer,
        if (_selectedPdfFile != null)
          DrawingOverlay(
            settingsNotifier: _drawingSettingsNotifier,
            strokesNotifier: _drawingStrokesNotifier,
            pdfViewerController: _pdfViewerController,
            onStrokeAdded: _scheduleAutoSave,
          ),
      ],
    );

    // Dark mode filter
    if (SettingsService().isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255, // Red
          0, -1, 0, 0, 255, // Green
          0, 0, -1, 0, 255, // Blue
          0, 0, 0, 1, 0, // Alpha
        ]),
        child: viewer,
      );
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final keys = HardwareKeyboard.instance.logicalKeysPressed;
            final isCtrlPressed =
                keys.contains(LogicalKeyboardKey.controlLeft) ||
                    keys.contains(LogicalKeyboardKey.controlRight) ||
                    keys.contains(LogicalKeyboardKey.metaLeft) ||
                    keys.contains(LogicalKeyboardKey.metaRight);
            if (isCtrlPressed) {
              final zoomDelta = pointerSignal.scrollDelta.dy < 0 ? 0.1 : -0.1;
              double baseZoom = _currentZoom >= 1.0
                  ? _pdfViewerController.zoomLevel
                  : _currentZoom;
              _setZoom(baseZoom + zoomDelta);
            }
          }
        },
        child: viewer,
      );
    }

    return viewer;
  }

  Widget _buildTimerButton(ThemeData theme, int elapsed) {
    final isRunning = _isTimerRunning;
    final d = Duration(seconds: elapsed);
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    final timeStr = hours > 0
        ? '${'timer_hours'.tr(args: [
                hours.toString()
              ])} ${'timer_minutes'.tr(args: [
                mins.toString()
              ])} ${'timer_seconds'.tr(args: [secs.toString()])}'
        : '${'timer_minutes'.tr(args: [
                mins.toString()
              ])} ${'timer_seconds'.tr(args: [
                secs.toString().padLeft(2, '0')
              ])}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRunning ? _pauseTimer : _startTimer,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1A22),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, offset: Offset(0, 4), blurRadius: 6)
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Icon(Icons.schedule,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 13),
              ),
              const SizedBox(width: 12),
              Icon(
                isRunning ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: isRunning ? Colors.white : theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listenable builder to react to dark mode toggle only for this screen level,
    // although inheriting from main layout might already do it, this is safe.
    return ListenableBuilder(
        listenable: SettingsService(),
        builder: (context, _) {
          return Scaffold(
            appBar: _selectedPdfFile != null
                ? AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          _closePdf();
                        }
                      },
                    ),
                    title: _isSearching
                        ? TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: 'pdf_search_hint'.tr(),
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                            style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16),
                            onSubmitted: (value) async {
                              if (value.isNotEmpty) {
                                _searchResult =
                                    _pdfViewerController.searchText(value);
                                setState(() {});
                              }
                            },
                          )
                        : Text(_pdfName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    centerTitle: false,
                    elevation: 0,
                    actions: [
                      if (_isSearching) ...[
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up),
                          onPressed: _searchResult.hasResult
                              ? () {
                                  _searchResult.previousInstance();
                                  setState(() {});
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down),
                          onPressed: _searchResult.hasResult
                              ? () {
                                  _searchResult.nextInstance();
                                  setState(() {});
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                              _searchResult.clear();
                            });
                          },
                        ),
                      ] else ...[
                        // Geri al butonu (UndoHistoryController'a bağlı)
                        ValueListenableBuilder<UndoHistoryValue>(
                          valueListenable: _undoController,
                          builder: (context, value, child) {
                            return IconButton(
                              icon: const Icon(Icons.undo),
                              tooltip: 'Geri Al',
                              onPressed: value.canUndo
                                  ? () => _undoController.undo()
                                  : null,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                            Future.delayed(const Duration(milliseconds: 100),
                                () => _searchFocusNode.requestFocus());
                          },
                          padding: const EdgeInsets.only(right: 8),
                        ),
                        // Çizim modu butonu
                        ValueListenableBuilder<DrawingSettings>(
                          valueListenable: _drawingSettingsNotifier,
                          builder: (context, settings, _) {
                            final isDrawing = settings.isDrawingMode;
                            return IconButton(
                              icon: Icon(
                                isDrawing
                                    ? Icons.edit_off_outlined
                                    : Icons.edit_outlined,
                                color: isDrawing
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              tooltip: 'Çizim',
                              onPressed: () {
                                _drawingSettingsNotifier.value =
                                    settings.copyWith(
                                  isDrawingMode: !isDrawing,
                                );
                                if (isDrawing) {
                                  // Moddan çıkıldı — çizimleri SQLite'a kaydet
                                  _saveDrawingStrokes();
                                  // Ayrıca PDF annotation kaydetmeyi tetikle
                                  _autoSaveTimer?.cancel();
                                  _autoSaveTimer =
                                      Timer(const Duration(milliseconds: 500),
                                          () async {
                                    await _autoSaveAnnotations();
                                  });
                                }
                              },
                              padding: const EdgeInsets.only(right: 8),
                            );
                          },
                        ),
                        // Kütüphaneye kaydet butonu
                        _isSavingToLibrary
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.bookmark_add_outlined),
                                tooltip: 'pdf_save_to_library'.tr(),
                                onPressed: _savePdfToLibrary,
                                padding: const EdgeInsets.only(right: 8),
                              ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'pdf_upload_tooltip'.tr(),
                          onPressed: _pickPdf,
                          padding: const EdgeInsets.only(right: 16),
                        ),
                      ],
                    ],
                  )
                : AppBar(
                    title: const LumoriaLogo(iconSize: 28, fontSize: 18),
                    centerTitle: false,
                    elevation: 0,
                  ),
            body: _selectedPdfFile == null
                ? _buildEmptyState(theme)
                : Stack(
                    children: [
                      _buildPdfViewer(),
                      if (_selectedPdfFile != null)
                        DrawingMenu(
                          settingsNotifier: _drawingSettingsNotifier,
                          onClearStrokes: () {
                            _drawingStrokesNotifier.value = [];
                            _saveDrawingStrokes();
                            _scheduleAutoSave();
                          },
                        ),
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface
                                  .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.zoom_out),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _zoomOut,
                                ),
                                const SizedBox(width: 4),
                                ValueListenableBuilder<int>(
                                  valueListenable: _currentPageNotifier,
                                  builder: (context, current, child) {
                                    return ValueListenableBuilder<int>(
                                      valueListenable: _totalPagesNotifier,
                                      builder: (context, total, child) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$current / $total',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.zoom_in),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _zoomIn,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_tooltipText != null && _tooltipRect != null)
                        _buildInlineTooltip(),
                    ],
                  ),
            floatingActionButton: _selectedPdfFile != null
                ? ValueListenableBuilder<String?>(
                    valueListenable: _selectedTextNotifier,
                    builder: (context, selectedText, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (SettingsService().showTimerIcon)
                            Positioned(
                              left: _timerPosition.dx,
                              top: _timerPosition.dy,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  final screenSize =
                                      MediaQuery.of(context).size;
                                  setState(() {
                                    double dx =
                                        _timerPosition.dx + details.delta.dx;
                                    double dy =
                                        _timerPosition.dy + details.delta.dy;
                                    dx =
                                        dx.clamp(0.0, screenSize.width - 150.0);
                                    dy =
                                        dy.clamp(0.0, screenSize.height - 60.0);
                                    _timerPosition = Offset(dx, dy);
                                  });
                                },
                                child: ValueListenableBuilder<int>(
                                  valueListenable:
                                      SettingsService.activeSessionTime,
                                  builder: (context, elapsed, _) {
                                    return _buildTimerButton(theme, elapsed);
                                  },
                                ),
                              ),
                            ),
                          if (selectedText != null && _tooltipText == null)
                            Positioned(
                              bottom: 30, // Move to bottom safe area
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final text = _selectedTextNotifier.value;
                                          if (text != null) {
                                            _pdfViewerController.clearSelection();
                                            _selectedTextNotifier.value = null;
                                            _selectedTextRectNotifier.value = null;
                                            _showSaveQuoteDialog(text);
                                          }
                                        },
                                        icon: const Icon(Icons.format_quote),
                                        label: Text('pdf_quote_btn'.tr(),
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.tertiary,
                                          foregroundColor: theme.colorScheme.onTertiary,
                                          elevation: 0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          final text = _selectedTextNotifier.value;
                                          final rect = _selectedTextRectNotifier.value;
                                          if (text != null && rect != null) {
                                            _pdfViewerController.clearSelection();
                                            _selectedTextNotifier.value = null;
                                            _selectedTextRectNotifier.value = null;
                                            _showTooltip(text, rect);
                                          }
                                        },
                                        icon: const Icon(CupertinoIcons.wand_stars),
                                        label: Text('pdf_analyze_btn'.tr(),
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: theme.colorScheme.surface,
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                : null,
          );
        });
  }

  void _showSaveQuoteDialog(String text) async {
    final folders = await DatabaseHelper.instance.fetchAllFolders();
    final quoteFolders = folders.where((f) => (f['category'] ?? 'notes') == 'quotes').toList();
    int? selectedFolderId;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('pdf_quote_btn'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$text"',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              if (quoteFolders.isNotEmpty)
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
                    ...quoteFolders.map((f) => DropdownMenuItem<int>(
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
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.insertQuote({
                  'quotedText': text,
                  'pdfName': _pdfName,
                  'pageNumber': _currentPageNotifier.value,
                  'date': DateTime.now().toIso8601String(),
                  'folderId': selectedFolderId,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  _pdfViewerController.clearSelection();
                  _selectedTextNotifier.value = null;
                  _selectedTextRectNotifier.value = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('pdf_quote_saved'.tr()),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        // Radial Gradients
        Positioned(
          top: -150,
          right: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main Content
        SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Upload Card
                    GestureDetector(
                      onTap: _pickPdf,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 40, horizontal: 24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : const Color(0xFFF0F5FD),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_upload,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'pdf_browse_files_title'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.folder_open, size: 20),
                                label: Text('pdf_browse'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Recent Documents Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'pdf_recent_documents'.tr(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Empty for now, wait for navigation
                          },
                          child: Text(
                            'pdf_view_all'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Recent files list
                    if (_isLoadingRecent)
                      const Center(child: CircularProgressIndicator())
                    else if (_recentPdfs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('pdf_no_documents'.tr(),
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      )
                    else
                      ..._recentPdfs
                          .map((pdf) => _buildRecentPdfCard(pdf, theme)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPdfCard(Map<String, dynamic> item, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final fileExists =
        item['filePath'] != null && File(item['filePath']).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: fileExists
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PdfViewScreen(initialFilePath: item['filePath']),
                    ),
                  );
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf,
                      color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['pdfName'] ?? 'Belge',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: fileExists
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileExists
                            ? (item['date']?.substring(0, 10) ?? '')
                            : 'Dosya Bulunamadı',
                        style: TextStyle(
                          fontSize: 13,
                          color: fileExists
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (fileExists)
                  Icon(Icons.visibility,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Icon(Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
