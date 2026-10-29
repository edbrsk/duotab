import 'package:flutter_bloc/flutter_bloc.dart';

import '../../engine/engine_bridge.dart';
import '../../engine/protocol.dart';

class ScoreState {
  final SongSummary? song;

  /// Relative to the app's Documents folder.
  final String? path;
  final int? selectedTrackIndex;
  final bool loading;
  final String? error;

  const ScoreState({
    this.song,
    this.path,
    this.selectedTrackIndex,
    this.loading = false,
    this.error,
  });
}

class ScoreCubit extends Cubit<ScoreState> {
  final EngineBridge engine;

  ScoreCubit({required this.engine}) : super(const ScoreState());

  Future<void> open(String path) async {
    emit(
      ScoreState(
        song: state.song,
        path: state.path,
        selectedTrackIndex: state.selectedTrackIndex,
        loading: true,
      ),
    );
    try {
      final song = await engine.open(path);
      final first = song.guitarTracks.firstOrNull?.index;
      if (first != null) await engine.renderTrack(first);
      emit(ScoreState(song: song, path: path, selectedTrackIndex: first));
    } on Exception catch (e) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: state.selectedTrackIndex,
          error: e is EngineException ? e.message : '$e',
        ),
      );
    }
  }

  Future<void> selectTrack(int trackIndex) async {
    await engine.renderTrack(trackIndex);
    emit(
      ScoreState(
        song: state.song,
        path: state.path,
        selectedTrackIndex: trackIndex,
      ),
    );
  }
}
