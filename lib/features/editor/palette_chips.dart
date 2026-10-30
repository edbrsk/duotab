import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';

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

class PaletteGlyph extends StatelessWidget {
  final String glyph;

  const PaletteGlyph(this.glyph, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    glyph,
    style: const TextStyle(fontFamily: 'Bravura', fontSize: 22, height: 1),
  );
}

/// Guitar Pro's printed abbreviation, for a technique without a SMuFL symbol.
class PaletteText extends StatelessWidget {
  final String text;

  const PaletteText(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 14, height: 1));
}
