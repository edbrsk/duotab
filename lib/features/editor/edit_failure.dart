import '../../l10n/app_localizations.dart';

/// What the owner reads for an edit the engine refused, from its message.
String editFailureMessage(AppLocalizations l10n, String message) =>
    switch (message) {
      'no free MIDI channel' => l10n.editFailedNoChannel,
      'a track needs a name' => l10n.editFailedNoName,
      'the song keeps one guitar track' => l10n.editFailedLastGuitar,
      "this bar ends a repeat that can't move" => l10n.editFailedRepeat,
      _ => l10n.editFailed,
    };
