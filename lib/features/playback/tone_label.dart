import '../../l10n/app_localizations.dart';
import 'tone.dart';

String toneLabel(AppLocalizations l10n, Tone tone) => switch (tone) {
  Tone.clean => l10n.toneClean,
  Tone.overdrive => l10n.toneOverdrive,
  Tone.highGain => l10n.toneHighGain,
};
