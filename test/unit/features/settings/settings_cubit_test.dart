import 'dart:io';

import 'package:duotab/core/storage/json_file.dart';
import 'package:duotab/features/playback/tone.dart';
import 'package:duotab/features/settings/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings_cubit_test');
    file = File(p.join(dir.path, 'settings.json'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('loads defaults when nothing is stored', () async {
    final cubit = SettingsCubit(JsonFile(file));
    await cubit.load();
    expect(cubit.state.countIn, isFalse);
    expect(cubit.state.metronome, isFalse);
    expect(cubit.state.defaultTone, Tone.clean);
    expect(cubit.state.trackPanelCollapsed, isFalse);
    await cubit.close();
  });

  test('persists each setting', () async {
    final cubit = SettingsCubit(JsonFile(file));
    await cubit.load();
    await cubit.setCountIn(on: true);
    await cubit.setMetronome(on: true);
    await cubit.setDefaultTone(Tone.overdrive);
    await cubit.setTrackPanelCollapsed(collapsed: true);
    await cubit.close();

    final fresh = SettingsCubit(JsonFile(file));
    await fresh.load();
    expect(fresh.state.countIn, isTrue);
    expect(fresh.state.metronome, isTrue);
    expect(fresh.state.defaultTone, Tone.overdrive);
    expect(fresh.state.trackPanelCollapsed, isTrue);
    await fresh.close();
  });
}
