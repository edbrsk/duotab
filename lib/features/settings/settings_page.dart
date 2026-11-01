import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/app_logo_header.dart';
import '../playback/tone.dart';
import '../playback/tone_label.dart';
import 'licences_page.dart';
import 'settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SettingsCubit>();
    final settings = context.watch<SettingsCubit>().state;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: ListView(
          children: [
            const AppLogoHeader(),
            SwitchListTile(
              title: Text(l10n.countIn),
              value: settings.countIn,
              onChanged: (on) => cubit.setCountIn(on: on),
            ),
            SwitchListTile(
              title: Text(l10n.metronome),
              value: settings.metronome,
              onChanged: (on) => cubit.setMetronome(on: on),
            ),
            ListTile(
              title: Text(l10n.defaultTone),
              trailing: DropdownButton<Tone>(
                value: settings.defaultTone,
                underline: const SizedBox.shrink(),
                onChanged: (tone) {
                  if (tone != null) cubit.setDefaultTone(tone);
                },
                items: [
                  for (final tone in Tone.values)
                    DropdownMenuItem(
                      value: tone,
                      child: Text(toneLabel(l10n, tone)),
                    ),
                ],
              ),
            ),
            ListTile(
              title: Text(l10n.licences),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LicencesPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
