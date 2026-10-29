import '../../engine/protocol.dart';
import 'practice_settings.dart';
import 'tone.dart';

/// One [TrackPractice] per track of [song]: saved settings first, then the
/// file's program when it is a tone, then [defaultTone] for guitar tracks.
PracticeSettings resolvePractice(
  SongSummary song,
  PracticeSettings? saved,
  Tone defaultTone,
) {
  final base = saved ?? const PracticeSettings();
  return base.copyWith(
    tracks: {
      for (final track in song.tracks)
        track.index: _resolveTrack(
          track,
          base.tracks[track.index],
          defaultTone,
        ),
    },
  );
}

TrackPractice _resolveTrack(
  TrackSummary track,
  TrackPractice? saved,
  Tone defaultTone,
) {
  final practice = saved ?? const TrackPractice();
  if (track.kind != TrackKind.guitar) {
    return TrackPractice(
      mute: practice.mute,
      solo: practice.solo,
      showNotation: practice.showNotation,
      showTab: practice.showTab,
    );
  }
  return practice.copyWith(
    tone: practice.tone ?? Tone.fromProgram(track.midiProgram) ?? defaultTone,
  );
}
