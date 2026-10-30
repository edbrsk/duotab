import 'dart:io';

import 'package:duoscore/engine/engine_bridge.dart';
import 'package:duoscore/engine/protocol.dart';
import 'package:duoscore/features/editor/song_saver.dart';
import 'package:duoscore/features/export/export_channel.dart';
import 'package:duoscore/features/export/song_exporter.dart';
import 'package:duoscore/features/playback/practice_settings.dart';
import 'package:duoscore/features/playback/practice_store.dart';
import 'package:duoscore/features/score/score_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _Engine extends Mock implements EngineBridge {}

class _Score extends Mock implements ScoreCubit {}

class _Channel extends Mock implements ExportChannel {}

class _Saver extends Mock implements SongSaver {}

class _Practice extends Mock implements PracticeStore {}

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

  late Directory documents;
  late _Saver saver;
  late _Practice practice;

  setUpAll(() {
    registerFallbackValue(Rect.zero);
    registerFallbackValue(<StaffView>[]);
  });

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('exports');
    documents = await Directory.systemTemp.createTemp('documents');
    saver = _Saver();
    practice = _Practice();
    when(() => saver.flush()).thenAnswer((_) async {});
    when(() => saver.idle).thenAnswer((_) async {});
    when(() => practice.load(any())).thenAnswer((_) async => null);
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
      documents: documents,
      saver: saver,
      practice: practice,
    );
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
    await documents.delete(recursive: true);
  });

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

  group('a song from the library', () {
    void stubPdf() {
      when(
        () => channel.makePdf(
          pages: any(named: 'pages'),
          baseUrl: any(named: 'baseUrl'),
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) async {});
    }

    test('a .gp song is shared as the file itself, under its name', () async {
      File(p.join(documents.path, 'a (DuoScore).gp')).writeAsBytesSync([7, 8]);
      await exporter.shareFile('a (DuoScore).gp', 'a', ExportFormat.gp, anchor);
      expect(await File(exportPath('a.gp')).readAsBytes(), [7, 8]);
      verify(() => channel.share([exportPath('a.gp')], anchor)).called(1);
      verifyNever(() => engine.exportFileGp(any()));
    });

    test('another format is converted to .gp by the engine', () async {
      when(() => engine.exportFileGp('b.gp5'))
          .thenAnswer((_) async => Uint8List.fromList([4]));
      await exporter.shareFile('b.gp5', 'b', ExportFormat.gp, anchor);
      expect(await File(exportPath('b.gp')).readAsBytes(), [4]);
    });

    test('a PDF uses the staves chosen for the song', () async {
      when(() => practice.load('a.gp')).thenAnswer(
        (_) async =>
            const PracticeSettings(tracks: {1: TrackPractice(showTab: false)}),
      );
      when(() => engine.exportFilePdf(any(), any())).thenAnswer(
        (_) async => const PdfPages(pages: ['<p>1</p>'], baseUrl: 'http://h/'),
      );
      stubPdf();
      await exporter.shareFile('a.gp', 'a', ExportFormat.pdf, anchor);
      final staves =
          verify(() => engine.exportFilePdf('a.gp', captureAny()))
                  .captured
                  .single
              as List<StaffView>;
      expect(staves.single.index, 1);
      expect(staves.single.tab, isFalse);
      expect(staves.single.notation, isTrue);
      verify(
        () => channel.makePdf(
          pages: ['<p>1</p>'],
          baseUrl: 'http://h/',
          path: exportPath('a.pdf'),
        ),
      ).called(1);
    });

    test(
      'a first edit saved by the export is exported from its copy',
      () async {
        File(p.join(documents.path, 'a (DuoScore).gp')).writeAsBytesSync([6]);
        var path = 'a.gp';
        when(() => score.state).thenAnswer(
          (_) => ScoreState(
            song: const SongSummary(title: 'a', tracks: []),
            path: path,
          ),
        );
        when(() => saver.flush())
            .thenAnswer((_) async => path = 'a (DuoScore).gp');
        await exporter.shareFile('a.gp', 'a', ExportFormat.gp, anchor);
        expect(await File(exportPath('a.gp')).readAsBytes(), [6]);
      },
    );

    test('pending edits are saved before the export', () async {
      File(p.join(documents.path, 'a.gp')).writeAsBytesSync([1]);
      await exporter.shareFile('a.gp', 'a', ExportFormat.gp, anchor);
      verifyInOrder([() => saver.flush(), () => channel.share(any(), any())]);
    });
  });
}
