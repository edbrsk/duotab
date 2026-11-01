import 'package:flutter/material.dart';

/// A chord box: the low string on the left, five frets from [firstFret].
class ChordDiagram extends StatelessWidget {
  static const _frets = 5;

  /// Low string first; −1 for a string not played.
  final List<int> frets;
  final int firstFret;

  const ChordDiagram({required this.frets, required this.firstFret, super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(56, 66),
    painter: _DiagramPainter(
      frets,
      firstFret,
      Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _DiagramPainter extends CustomPainter {
  final List<int> frets;
  final int firstFret;
  final Color color;

  _DiagramPainter(this.frets, this.firstFret, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const top = 12.0;
    const side = 6.0;
    final strings = frets.length;
    final gapX = (size.width - 2 * side) / (strings - 1);
    final gapY = (size.height - top - 2) / ChordDiagram._frets;
    final line = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var s = 0; s < strings; s++) {
      final x = side + s * gapX;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + ChordDiagram._frets * gapY),
        line,
      );
    }
    for (var f = 0; f <= ChordDiagram._frets; f++) {
      final y = top + f * gapY;
      canvas.drawLine(
        Offset(side, y),
        Offset(side + (strings - 1) * gapX, y),
        f == 0 && firstFret == 1
            ? (Paint()
                ..color = color
                ..strokeWidth = 3)
            : line,
      );
    }
    final dot = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final (s, fret) in frets.indexed) {
      final x = side + s * gapX;
      if (fret < 0) {
        const r = 2.6;
        canvas
          ..drawLine(
            Offset(x - r, top - 7 - r),
            Offset(x + r, top - 7 + r),
            ring,
          )
          ..drawLine(
            Offset(x - r, top - 7 + r),
            Offset(x + r, top - 7 - r),
            ring,
          );
      } else if (fret == 0) {
        canvas.drawCircle(Offset(x, top - 7), 2.6, ring);
      } else {
        canvas.drawCircle(
          Offset(x, top + (fret - firstFret + 0.5) * gapY),
          3.4,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DiagramPainter old) =>
      old.frets.join() != frets.join() ||
      old.firstFret != firstFret ||
      old.color != color;
}
