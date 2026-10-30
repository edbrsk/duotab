import 'package:duoscore/engine/protocol.dart';

TrackSummary track(int index, String name, TrackKind kind) => TrackSummary(
  index: index,
  name: name,
  kind: kind,
  stringCount: kind == TrackKind.guitar ? 6 : null,
  tuning: kind == TrackKind.guitar ? const [64, 59, 55, 50, 45, 40] : null,
  midiProgram: 29,
);

final drumsAndTwoGuitars = SongSummary(
  title: 'Fixture',
  tracks: [
    track(0, 'Drums', TrackKind.drums),
    track(1, 'Guitar 1', TrackKind.guitar),
    track(2, 'Guitar 2', TrackKind.guitar),
  ],
);

final drumsOnly = SongSummary(
  title: 'Beat',
  tracks: [track(0, 'Drums', TrackKind.drums)],
);
