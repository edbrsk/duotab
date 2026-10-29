import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../playback/tone.dart';
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
            ListTile(title: Text(l10n.defaultTone)),
            RadioGroup<Tone>(
              groupValue: settings.defaultTone,
              onChanged: (tone) {
                if (tone != null) cubit.setDefaultTone(tone);
              },
              child: Column(
                children: [
                  for (final tone in Tone.values)
                    RadioListTile<Tone>(
                      value: tone,
                      title: Text(toneLabel(l10n, tone)),
                    ),
                ],
              ),
            ),
            ListTile(
              title: Text(l10n.licences),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  showLicensePage(context: context, applicationName: 'DuoTab'),
            ),
          ],
        ),
      ),
    );
  }
}

String toneLabel(AppLocalizations l10n, Tone tone) => switch (tone) {
  Tone.clean => l10n.toneClean,
  Tone.overdrive => l10n.toneOverdrive,
  Tone.highGain => l10n.toneHighGain,
};
