import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/json_file.dart';
import '../playback/tone.dart';

class AppSettings {
  final bool countIn;
  final bool metronome;

  /// For guitar tracks whose file program is not one of the tones.
  final Tone defaultTone;

  const AppSettings({
    this.countIn = false,
    this.metronome = false,
    this.defaultTone = Tone.clean,
  });

  AppSettings copyWith({bool? countIn, bool? metronome, Tone? defaultTone}) =>
      AppSettings(
        countIn: countIn ?? this.countIn,
        metronome: metronome ?? this.metronome,
        defaultTone: defaultTone ?? this.defaultTone,
      );
}

class SettingsCubit extends Cubit<AppSettings> {
  final JsonFile file;

  SettingsCubit(this.file) : super(const AppSettings());

  Future<void> load() async {
    final json = await file.read();
    emit(
      AppSettings(
        countIn: json['countIn'] == true,
        metronome: json['metronome'] == true,
        defaultTone:
            Tone.values
                .where((t) => t.name == json['defaultTone'])
                .firstOrNull ??
            Tone.clean,
      ),
    );
  }

  Future<void> setCountIn({required bool on}) =>
      _update(state.copyWith(countIn: on));

  Future<void> setMetronome({required bool on}) =>
      _update(state.copyWith(metronome: on));

  Future<void> setDefaultTone(Tone tone) =>
      _update(state.copyWith(defaultTone: tone));

  Future<void> _update(AppSettings settings) async {
    emit(settings);
    await file.write({
      'countIn': settings.countIn,
      'metronome': settings.metronome,
      'defaultTone': settings.defaultTone.name,
    });
  }
}
