import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';
import 'smufl_bounds.dart';

class PaletteGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const PaletteGroup({required this.title, required this.children, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(spacing: Spacing.xs, runSpacing: Spacing.xs, children: children),
      ],
    ),
  );
}

class PaletteChip extends StatelessWidget {
  final String tooltip;
  final Widget label;
  final bool selected;
  final VoidCallback? onSelected;

  const PaletteChip({
    required this.tooltip,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: ChoiceChip(
      label: label,
      selected: selected,
      showCheckmark: false,
      backgroundColor: AppColors.key,
      selectedColor: AppColors.accent,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
    ),
  );
}

/// A Bravura symbol, fitted and centred by its ink, which in a music font
/// reaches well past the line. Its size is fixed, as an icon's is.
class PaletteGlyph extends StatelessWidget {
  static const _fontSize = 22.0;

  /// The ink may reach past the 22 pt square into the chip's own padding.
  static const _inkBox = 30.0;

  final String glyph;

  const PaletteGlyph(this.glyph, {super.key});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      const TextStyle(fontFamily: 'Bravura', fontSize: _fontSize, height: 1),
    );
    final runes = glyph.runes;
    final bounds = runes.length == 1 ? smuflBounds[runes.single] : null;
    if (bounds == null) {
      return Text(glyph, style: style, textScaler: TextScaler.noScaling);
    }
    return SizedBox.square(
      dimension: _fontSize,
      child: CustomPaint(painter: _GlyphPainter(glyph, bounds, style)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final String glyph;
  final ({int left, int bottom, int right, int top}) bounds;
  final TextStyle style;

  _GlyphPainter(this.glyph, this.bounds, this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final b = bounds;
    final fontSize = math.min(
      style.fontSize!,
      PaletteGlyph._inkBox *
          1000 /
          math.max(b.right - b.left, b.top - b.bottom),
    );
    final em = fontSize / 1000;
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: style.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final inkCentre = Offset(
      (b.left + b.right) / 2 * em,
      baseline - (b.top + b.bottom) / 2 * em,
    );
    painter
      ..paint(canvas, size.center(Offset.zero) - inkCentre)
      ..dispose();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.style != style;
}

/// Guitar Pro's printed abbreviation, for a technique without a SMuFL symbol.
class PaletteText extends StatelessWidget {
  final String text;

  const PaletteText(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 14, height: 1));
}
