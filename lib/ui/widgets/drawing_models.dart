import 'dart:convert';
import 'package:flutter/material.dart';

class DrawingSettings {
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool isEraser;
  final bool isDrawingMode;

  const DrawingSettings({
    this.color = Colors.red,
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.isEraser = false,
    this.isDrawingMode = false,
  });

  DrawingSettings copyWith({
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isEraser,
    bool? isDrawingMode,
  }) {
    return DrawingSettings(
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isEraser: isEraser ?? this.isEraser,
      isDrawingMode: isDrawingMode ?? this.isDrawingMode,
    );
  }
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  Path? cachedPath;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.cachedPath,
  });

  /// JSON'a çevir (kalıcı kayıt için)
  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  /// JSON'dan oluştur (yükleme için)
  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List)
        .map((p) =>
            Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble()))
        .toList();

    final stroke = DrawingStroke(
      points: points,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
    );

    // Path'i hemen önbelleğe al
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      stroke.cachedPath = path;
    }

    return stroke;
  }

  /// Stroke listesini JSON string'e çevir
  static String encodeList(List<DrawingStroke> strokes) {
    return jsonEncode(strokes.map((s) => s.toJson()).toList());
  }

  /// JSON string'den stroke listesi oluştur
  static List<DrawingStroke> decodeList(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map((item) => DrawingStroke.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
