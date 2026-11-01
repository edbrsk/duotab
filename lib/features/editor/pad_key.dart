import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';

const kPadKeyHeight = 44.0;

class PadKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const PadKey({
    required this.onPressed,
    this.label,
    this.icon,
    this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final key = Material(
      color: AppColors.key,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          height: kPadKeyHeight,
          child: Center(
            child: icon != null
                ? Icon(icon, size: IconSizes.md)
                : Text(label!, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip, child: key);
  }
}
