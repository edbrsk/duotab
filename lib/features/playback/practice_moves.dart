import '../../engine/protocol.dart';
import 'practice_settings.dart';

/// [practice] reindexed for [after]'s tracks: each track keeps the practice
/// of the track in [before] with the same MIDI channel, the first unmatched
/// one when channels repeat. A track that left is kept in [parked], so an
/// undo that brings it back finds its practice again.
Map<int, TrackPractice> movePractice(
  SongSummary before,
  SongSummary after,
  Map<int, TrackPractice> practice, {
  Map<String, TrackPractice>? parked,
}) {
  final unmatched = [...before.tracks];
  final moved = <int, TrackPractice>{};
  for (final track in after.tracks) {
    final at = unmatched.indexWhere((t) => t.channel == track.channel);
    final found = at >= 0
        ? practice[unmatched.removeAt(at).index]
        : parked?.remove(_parkingKey(track));
    if (found != null) moved[track.index] = found;
  }
  for (final left in unmatched) {
    if (practice[left.index] case final p?) parked?[_parkingKey(left)] = p;
  }
  return moved;
}

// A new track can take a removed track's channel; only the same track,
// brought back by undo, has the same name, tuning and notes as well.
String _parkingKey(TrackSummary track) =>
    '${track.channel}|${track.name}|${track.tuning}|${track.barsWithNotes}';
