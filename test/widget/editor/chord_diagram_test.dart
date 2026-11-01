import 'package:duoscore/features/editor/chord_diagram.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Size> sizeFor(WidgetTester tester, int strings) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChordDiagram(frets: List.filled(strings, 3), firstFret: 1),
        ),
      ),
    );
    return tester.getSize(find.byType(ChordDiagram));
  }

  testWidgets('strings stay a dot apart on any guitar', (tester) async {
    for (final strings in [6, 7, 8]) {
      final width = (await sizeFor(tester, strings)).width;
      // 6 pt either side; the dots are 6.8 pt across.
      expect(
        (width - 12) / (strings - 1),
        greaterThanOrEqualTo(7),
        reason: '$strings',
      );
    }
  });

  testWidgets('six strings keep the compact box', (tester) async {
    expect(await sizeFor(tester, 6), const Size(56, 66));
  });
}
