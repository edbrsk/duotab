import 'package:flutter/material.dart';

import '../../core/design/design_tokens.dart';

class AppNameHeader extends StatelessWidget {
  const AppNameHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
    child: Center(
      child: Text(
        'DuoScore',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          // iOS ships Didot, the serif of engraved scores; Georgia stands in.
          fontFamily: 'Didot',
          fontFamilyFallback: const ['Georgia'],
          letterSpacing: 1,
        ),
      ),
    ),
  );
}
