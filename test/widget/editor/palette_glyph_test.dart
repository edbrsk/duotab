import 'package:duoscore/core/design/design_tokens.dart';
import 'package:duoscore/features/editor/palette_chips.dart';
import 'package:duoscore/features/editor/smufl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _margin = 24.0;

final _glyphs = <String>[
  ...Smufl.notes.values,
  ...Smufl.rests.values,
  ...Smufl.tuplets.values,
  ...Smufl.dynamics.values,
  for (final glyph in [
    Smufl.augmentationDot,
    Smufl.graceNote,
    Smufl.doubleFlat,
    Smufl.flat,
    Smufl.natural,
    Smufl.sharp,
    Smufl.doubleSharp,
    Smufl.accent,
    Smufl.marcato,
    Smufl.staccato,
    Smufl.tenuto,
    Smufl.fermata,
    Smufl.vibrato,
    Smufl.deadNote,
    Smufl.pickDown,
    Smufl.pickUp,
    Smufl.tremolo,
    Smufl.gClef,
    Smufl.fClef,
    Smufl.repeatLeft,
    Smufl.repeatRight,
    Smufl.segno,
    Smufl.coda,
  ])
    glyph,
];

void main() {
  setUpAll(() async {
    final bravura = FontLoader('Bravura')
      ..addFont(rootBundle.load('assets/engine/alphatab/font/Bravura.otf'));
    await bravura.load();
  });

  /// Inked pixels outside the chip, drawn on a clear margin around it.
  Future<int> spilled(
    WidgetTester tester,
    String glyph, {
    double textScale = 1,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(_margin),
                // As the palette lays its chips out.
                child: Wrap(
                  children: [
                    PaletteChip(
                      tooltip: 'glyph',
                      label: PaletteGlyph(glyph),
                      selected: false,
                      onSelected: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // The chip's drawn surface, inside its larger tap target.
    final chip = tester.getRect(
      find
          .descendant(
            of: find.byType(ChoiceChip),
            matching: find.byType(Material),
          )
          .first,
    );
    final origin = tester.getTopLeft(find.byKey(key));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      var count = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final inside = chip
              .inflate(1)
              .contains(origin + Offset(x + 0.5, y + 0.5));
          if (!inside && bytes!.getUint8((y * image.width + x) * 4 + 3) > 0) {
            count++;
          }
        }
      }
      return count;
    }))!;
  }

  for (final glyph in _glyphs) {
    final name = 'U+${glyph.runes.first.toRadixString(16).toUpperCase()}';
    testWidgets('$name stays inside its key', (tester) async {
      expect(await spilled(tester, glyph), 0);
    });
    testWidgets('$name stays inside its key with large text', (tester) async {
      expect(await spilled(tester, glyph, textScale: 1.3), 0);
    });
  }

  testWidgets('a short glyph keeps the palette size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: PaletteGlyph(Smufl.sharp))),
    );
    final size = tester.getSize(find.byType(PaletteGlyph));
    expect(size.height, lessThanOrEqualTo(AccessibleSizes.minTouchTarget));
  });
}
