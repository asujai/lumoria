import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  try {
    final document = PdfDocument();
    final page = document.pages.add();

    // Create ink annotation
    final inkAnnotation =
        PdfInkAnnotation(const Rect.fromLTWH(10, 10, 100, 100), <List<Offset>>[
      <Offset>[const Offset(10, 10), const Offset(20, 20)]
    ]);
    inkAnnotation.color = PdfColor(255, 0, 0);
    page.annotations.add(inkAnnotation);
    print('SUCCESS: Created and added PdfInkAnnotation');
  } catch (e) {
    print('ERROR: \$e');
  }
}
