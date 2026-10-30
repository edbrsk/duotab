import '../../engine/protocol.dart';
import 'mix_level.dart';
import 'practice_settings.dart';
import 'tone.dart';

const minSpeed = 0.25;
const maxSpeed = 1.5;

/// One [TrackPractice] per track of [song]: saved settings first, then the
/// file's program when it is a tone, then [defaultTone] for guitar tracks. A
/// speed or loop the song can't have is dropped.
PracticeSettings resolvePractice(
  SongSummary song,
  PracticeSettings? saved,
  Tone defaultTone,
) {
  final base = saved ?? const PracticeSettings();
  final range = base.range;
  final lastBar = song.bars.lastOrNull?.startTick;
  final rangeFits =
      range != null &&
      range.startTick < range.endTick &&
      (lastBar == null || range.startTick <= lastBar);
  return base.copyWith(
    speed: base.speed.clamp(minSpeed, maxSpeed),
    range: () => rangeFits ? range : null,
    masterDb: base.masterDb ?? snapDb(song.masterDb),
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
  final volumeDb =
      practice.volumeDb ??
      switch (practice.legacyVolume) {
        final legacy? => dbFromLegacyVolume(legacy),
        null => snapDb(track.volumeDb),
      };
  final pan = practice.pan ?? track.pan;
  if (track.kind != TrackKind.guitar) {
    return TrackPractice(
      mute: practice.mute,
      solo: practice.solo,
      showNotation: practice.showNotation,
      showTab: practice.showTab,
      volumeDb: volumeDb,
      pan: pan,
    );
  }
  return practice.copyWith(
    tone:
        (practice.toneChosen ? practice.tone : null) ??
        Tone.fromProgram(track.midiProgram) ??
        defaultTone,
    volumeDb: volumeDb,
    pan: pan,
  );
}
