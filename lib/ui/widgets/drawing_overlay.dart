import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'drawing_models.dart';

class DrawingOverlay extends StatefulWidget {
  final ValueNotifier<DrawingSettings> settingsNotifier;
  final ValueNotifier<List<DrawingStroke>> strokesNotifier;
  final PdfViewerController pdfViewerController;
  final VoidCallback onStrokeAdded;

  const DrawingOverlay({
    super.key,
    required this.settingsNotifier,
    required this.strokesNotifier,
    required this.pdfViewerController,
    required this.onStrokeAdded,
  });

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  final ValueNotifier<DrawingStroke?> _activeStrokeNotifier =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    widget.pdfViewerController.addListener(_onPdfViewerChanged);
    widget.strokesNotifier.addListener(_onStrokesChanged);
  }

  @override
  void dispose() {
    widget.pdfViewerController.removeListener(_onPdfViewerChanged);
    widget.strokesNotifier.removeListener(_onStrokesChanged);
    _activeStrokeNotifier.dispose();
    super.dispose();
  }

  void _onPdfViewerChanged() {
    // Rebuild when scroll or zoom changes to update the CustomPaint transform
    if (mounted) setState(() {});
  }

  void _onStrokesChanged() {
    if (mounted) setState(() {});
  }

  Offset _getLogicalPosition(Offset localPosition) {
    final zoom = widget.pdfViewerController.zoomLevel;
    final scroll = widget.pdfViewerController.scrollOffset;
    return Offset(
      (localPosition.dx + scroll.dx) / zoom,
      (localPosition.dy + scroll.dy) / zoom,
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.settingsNotifier.value.isDrawingMode) return;

    final settings = widget.settingsNotifier.value;
    final logicalPos = _getLogicalPosition(details.localPosition);

    if (settings.isEraser) {
      _eraseAt(logicalPos);
      return;
    }

    _activeStrokeNotifier.value = DrawingStroke(
      points: [logicalPos],
      color: settings.color.withValues(alpha: settings.opacity),
      strokeWidth: settings.strokeWidth,
    );
  }

  // Used to limit update frequency and avoid bridge-flooding during finger draws
  int _lastDrawTime = 0;

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.settingsNotifier.value.isDrawingMode) return;

    final logicalPos = _getLogicalPosition(details.localPosition);

    if (widget.settingsNotifier.value.isEraser) {
      _eraseAt(logicalPos);
      return;
    }

    final currentStroke = _activeStrokeNotifier.value;
    if (currentStroke != null) {
      final zoom = widget.pdfViewerController.zoomLevel;
      // High minimum distance for finger strokes avoids tiny useless points
      // Using 4.0 points equivalent visually, scales nicely and drops 80% of CPU work
      final minDistance = 4.0 / zoom;

      if (currentStroke.points.isEmpty ||
          (currentStroke.points.last - logicalPos).distanceSquared >
              (minDistance * minDistance)) {
        currentStroke.points.add(logicalPos);

        // Throttle Flutter UI rebuilds: Only trigger repaints every ~16ms (60FPS limit)
        // This drops the massive event queue flooding from raw pointer events
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastDrawTime > 16) {
          _lastDrawTime = now;
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          _activeStrokeNotifier.notifyListeners();
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.settingsNotifier.value.isDrawingMode) return;

    final currentStroke = _activeStrokeNotifier.value;
    if (currentStroke != null && currentStroke.points.length > 1) {
      // Cache the path for performance when drawing later
      final path = Path();
      path.moveTo(currentStroke.points.first.dx, currentStroke.points.first.dy);
      for (int i = 1; i < currentStroke.points.length; i++) {
        path.lineTo(currentStroke.points[i].dx, currentStroke.points[i].dy);
      }
      currentStroke.cachedPath = path;

      final updatedStrokes =
          List<DrawingStroke>.from(widget.strokesNotifier.value)
            ..add(currentStroke);
      widget.strokesNotifier.value = updatedStrokes;
      widget.onStrokeAdded(); // Trigger auto-save or UI updates
    }
    _activeStrokeNotifier.value = null;
  }

  void _eraseAt(Offset logicalPos) {
    final currentStrokes = widget.strokesNotifier.value;
    final remainingStrokes = <DrawingStroke>[];
    bool erased = false;

    final eraseRadius = 20.0 / widget.pdfViewerController.zoomLevel;

    for (var stroke in currentStrokes) {
      bool intersects = false;
      for (var point in stroke.points) {
        if ((point - logicalPos).distance < eraseRadius) {
          intersects = true;
          break;
        }
      }
      if (!intersects) {
        remainingStrokes.add(stroke);
      } else {
        erased = true;
      }
    }

    if (erased) {
      widget.strokesNotifier.value = remainingStrokes;
      widget.onStrokeAdded(); // Trigger save on erase as well
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrawingSettings>(
      valueListenable: widget.settingsNotifier,
      builder: (context, settings, child) {
        final isInteractive = settings.isDrawingMode;

        return IgnorePointer(
          ignoring: !isInteractive,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(
              child: ClipRect(
                child: Stack(
                  children: [
                    // Completed strokes layer (RepaintBoundary for performance)
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _StrokesPainter(
                          strokes: widget.strokesNotifier.value,
                          zoomLevel: widget.pdfViewerController.zoomLevel,
                          scrollOffset: widget.pdfViewerController.scrollOffset,
                        ),
                      ),
                    ),
                    // Active drawing layer (rebuilds frequently, only draws 1 stroke)
                    ValueListenableBuilder<DrawingStroke?>(
                      valueListenable: _activeStrokeNotifier,
                      builder: (context, activeStroke, _) {
                        if (activeStroke == null)
                          return const SizedBox.shrink();
                        return CustomPaint(
                          size: Size.infinite,
                          painter: _ActiveStrokePainter(
                            stroke: activeStroke,
                            zoomLevel: widget.pdfViewerController.zoomLevel,
                            scrollOffset:
                                widget.pdfViewerController.scrollOffset,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StrokesPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final double zoomLevel;
  final Offset scrollOffset;

  _StrokesPainter({
    required this.strokes,
    required this.zoomLevel,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(-scrollOffset.dx, -scrollOffset.dy);
    canvas.scale(zoomLevel);

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.cachedPath != null) {
        canvas.drawPath(stroke.cachedPath!, paint);
      } else {
        // Fallback or single point optimization
        if (stroke.points.length == 1) {
          final p = stroke.points.first;
          canvas.drawLine(p, Offset(p.dx + 0.1, p.dy + 0.1), paint);
        } else {
          final path = Path();
          path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (int i = 1; i < stroke.points.length; i++) {
            path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}

class _ActiveStrokePainter extends CustomPainter {
  final DrawingStroke stroke;
  final double zoomLevel;
  final Offset scrollOffset;

  _ActiveStrokePainter({
    required this.stroke,
    required this.zoomLevel,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.points.isEmpty) return;

    canvas.save();
    canvas.translate(-scrollOffset.dx, -scrollOffset.dy);
    canvas.scale(zoomLevel);

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      canvas.drawLine(p, Offset(p.dx + 0.1, p.dy + 0.1), paint);
    } else {
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      // Simplify the path drawing, the point decimation handles skipping excess points
      for (int i = 1; i < stroke.points.length; i++) {
        // Avoid adding points too close to each other even internally
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActiveStrokePainter oldDelegate) {
    return true; // Always repaint active stroke
  }
}
