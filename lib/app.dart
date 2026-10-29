import 'package:flutter/material.dart';

import 'core/design/design_tokens.dart';
import 'l10n/app_localizations.dart';

class DuoTabApp extends StatelessWidget {
  final Widget home;

  const DuoTabApp({required this.home, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoTab',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
          surface: AppColors.panel,
        ),
      ),
      home: home,
    );
  }
}
