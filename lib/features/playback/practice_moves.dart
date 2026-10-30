import '../../engine/protocol.dart';
import 'practice_settings.dart';

/// [practice] reindexed for [after]'s tracks: each track keeps the practice
/// of the track in [before] with the same MIDI channel, the first unmatched
/// one when channels repeat. A track that left is kept in [parked] by
/// channel, so an undo that brings it back finds its practice again.
Map<int, TrackPractice> movePractice(
  SongSummary before,
  SongSummary after,
  Map<int, TrackPractice> practice, {
  Map<int, TrackPractice>? parked,
}) {
  final unmatched = [...before.tracks];
  final moved = <int, TrackPractice>{};
  for (final track in after.tracks) {
    final at = unmatched.indexWhere((t) => t.channel == track.channel);
    final found = at >= 0
        ? practice[unmatched.removeAt(at).index]
        : parked?.remove(track.channel);
    if (found != null) moved[track.index] = found;
  }
  for (final left in unmatched) {
    if (practice[left.index] case final p?) parked?[left.channel] = p;
  }
  return moved;
}
