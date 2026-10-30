import 'dart:io';

import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/export/export_channel.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _Engine extends Mock implements EngineBridge {}

class _Score extends Mock implements ScoreCubit {}

class _Channel extends Mock implements ExportChannel {}

void main() {
  late Directory temporary;
  late _Engine engine;
  late _Score score;
  late _Channel channel;
  late SongExporter exporter;
  const anchor = Rect.fromLTWH(1, 2, 3, 4);

  void titled(String title) => when(() => score.state).thenReturn(
    ScoreState(
      song: SongSummary(title: title, tracks: const []),
    ),
  );

  setUpAll(() => registerFallbackValue(Rect.zero));

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('exports');
    engine = _Engine();
    score = _Score();
    channel = _Channel();
    titled('Riff');
    when(() => channel.share(any(), any())).thenAnswer((_) async {});
    exporter = SongExporter(
      engine: engine,
      score: score,
      channel: channel,
      temporary: temporary,
    );
  });

  tearDown(() => temporary.delete(recursive: true));

  String exportPath(String name) => p.join(temporary.path, 'exports', name);

  test(
    "a .gp export writes the engine's bytes as <title>.gp and shares it",
    () async {
      when(() => engine.exportGp())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      await exporter.share(ExportFormat.gp, anchor);

      expect(await File(exportPath('Riff.gp')).readAsBytes(), [1, 2, 3]);
      verify(() => channel.share([exportPath('Riff.gp')], anchor)).called(1);
    },
  );

  test(
    "a PDF export renders the engine's pages into <title>.pdf and shares it",
    () async {
      when(() => engine.exportPdf()).thenAnswer(
        (_) async => const PdfPages(pages: ['<p>1</p>'], baseUrl: 'http://h/'),
      );
      when(
        () => channel.makePdf(
          pages: any(named: 'pages'),
          baseUrl: any(named: 'baseUrl'),
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) async {});

      await exporter.share(ExportFormat.pdf, anchor);

      verify(
        () => channel.makePdf(
          pages: ['<p>1</p>'],
          baseUrl: 'http://h/',
          path: exportPath('Riff.pdf'),
        ),
      ).called(1);
      verify(() => channel.share([exportPath('Riff.pdf')], anchor)).called(1);
    },
  );

  test(r'file names replace / \ : and fall back to Untitled', () {
    expect(SongExporter.fileName('AC/DC: Back', 'gp'), 'AC-DC- Back.gp');
    expect(SongExporter.fileName(r'a\b', 'gp'), 'a-b.gp');
    expect(SongExporter.fileName('  ', 'pdf'), 'Untitled.pdf');
  });

  test('each export clears the previous exports', () async {
    when(() => engine.exportGp()).thenAnswer((_) async => Uint8List(1));
    await exporter.share(ExportFormat.gp, anchor);
    titled('Other');

    await exporter.share(ExportFormat.gp, anchor);

    expect(
      Directory(p.join(temporary.path, 'exports'))
          .listSync()
          .map((f) => p.basename(f.path)),
      ['Other.gp'],
    );
  });

  test('a failed PDF shares nothing', () async {
    when(() => engine.exportPdf())
        .thenAnswer((_) async => const PdfPages(pages: [''], baseUrl: ''));
    when(
      () => channel.makePdf(
        pages: any(named: 'pages'),
        baseUrl: any(named: 'baseUrl'),
        path: any(named: 'path'),
      ),
    ).thenThrow(PlatformException(code: 'pdf_failed'));

    await expectLater(
      exporter.share(ExportFormat.pdf, anchor),
      throwsA(isA<PlatformException>()),
    );
    verifyNever(() => channel.share(any(), any()));
  });
}
