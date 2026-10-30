import 'package:flutter/material.dart';

import '../core/design/design_tokens.dart';
import '../l10n/app_localizations.dart';

/// Shown instead of the app when setting it up failed.
class StartupFailure extends StatelessWidget {
  final Object error;

  const StartupFailure({required this.error, super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text(
              AppLocalizations.of(context)!.startupFailed('$error'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
