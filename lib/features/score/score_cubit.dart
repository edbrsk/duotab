import 'dart:async';

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

  /// Changes each time a song is opened or created, and only then: an edit
  /// replaces [song] but is the same open song.
  final int openId;

  const ScoreState({
    this.song,
    this.path,
    this.selectedTrackIndex,
    this.loading = false,
    this.error,
    this.openId = 0,
  });
}

class ScoreCubit extends Cubit<ScoreState> {
  final EngineBridge engine;

  late final StreamSubscription<EngineEvent> _events;

  ScoreCubit({required this.engine}) : super(const ScoreState()) {
    _events = engine.events.listen((event) {
      // A ready with a song open means the engine page was reloaded.
      if (event.type == 'ready' && state.path != null) unawaited(_reopen());
    });
  }

  Future<void> _reopen() async {
    final track = state.selectedTrackIndex;
    await open(state.path!);
    if (track != null && track != state.selectedTrackIndex) {
      await selectTrack(track);
    }
  }

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }

  Future<void> open(String path) async {
    emit(
      ScoreState(
        song: state.song,
        path: state.path,
        selectedTrackIndex: state.selectedTrackIndex,
        loading: true,
        openId: state.openId,
      ),
    );
    await _show(() => engine.open(path), path);
  }

  Future<void> create(NewSongOptions options, String path) =>
      _show(() => engine.newSong(options), path);

  Future<void> _show(Future<SongSummary> Function() load, String path) async {
    final SongSummary song;
    try {
      song = await load();
    } on Object catch (e) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: state.selectedTrackIndex,
          error: _describe(e),
          openId: state.openId,
        ),
      );
      return;
    }
    // The engine now holds this song, so the state must too, even if the
    // render below fails; track indexes refer to it.
    final first = song.guitarTracks.firstOrNull?.index;
    emit(
      ScoreState(
        song: song,
        path: path,
        selectedTrackIndex: first,
        openId: state.openId + 1,
      ),
    );
    if (first != null) await _render(first);
  }

  /// The open song after an edit.
  void applyEdit(SongSummary song) => emit(
    ScoreState(
      song: song,
      path: state.path,
      selectedTrackIndex: state.selectedTrackIndex,
      openId: state.openId,
    ),
  );

  /// The open song is now saved at [path], such as its "(DuoTab)" copy.
  void moveTo(String path) => emit(
    ScoreState(
      song: state.song,
      path: path,
      selectedTrackIndex: state.selectedTrackIndex,
      openId: state.openId,
    ),
  );

  Future<void> selectTrack(int trackIndex) async {
    if (await _render(trackIndex)) {
      emit(
        ScoreState(
          song: state.song,
          path: state.path,
          selectedTrackIndex: trackIndex,
          openId: state.openId,
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
          openId: state.openId,
        ),
      );
      return false;
    }
  }

  static String _describe(Object error) =>
      error is EngineException ? error.message : '$error';
}
