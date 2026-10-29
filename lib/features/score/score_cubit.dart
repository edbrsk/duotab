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
    final SongSummary song;
    try {
      song = await engine.open(path);
    } on Object catch (e) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: state.selectedTrackIndex,
          error: _describe(e),
        ),
      );
      return;
    }
    // The engine now holds this song, so the state must too, even if the
    // render below fails; track indexes refer to it.
    final first = song.guitarTracks.firstOrNull?.index;
    emit(ScoreState(song: song, path: path, selectedTrackIndex: first));
    if (first != null) await _render(first);
  }

  Future<void> selectTrack(int trackIndex) async {
    if (await _render(trackIndex)) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: trackIndex,
        ),
      );
    }
  }

  Future<bool> _render(int trackIndex) async {
    try {
      await engine.renderTrack(trackIndex);
      return true;
    } on Object catch (e) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: state.selectedTrackIndex,
          error: _describe(e),
        ),
      );
      return false;
    }
  }

  static String _describe(Object error) =>
      error is EngineException ? error.message : '$error';
}
