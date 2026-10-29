# DuoTab Plan 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the music engine with a spike, then ship an iPhone Duo app that runs only unfolded, lists the songs in its Files folder, accepts files opened from other apps, and shows any guitar track as notation over tab.

**Architecture:** Flutter app (iOS only) structured like dreambudget: cubits for feature state, `get_it` for wiring, `ChangeNotifier` providers fed by native `EventChannel`s for the vertical-bar edge and the hinge. `crisp_notation_core` is the score model and file codecs, wrapped by DuoTab's own `Song`/`SongTrack` types so the rest of the app never imports codec functions directly; `crisp_notation` draws the score.

**Tech Stack:** Flutter 3.47.8, Dart 3, Swift (UIKit, iOS 27.1 SDK), `crisp_notation` / `crisp_notation_core` 0.13.x, `flutter_bloc`, `get_it`, `provider`, `path_provider`, `flutter_localizations` + `intl`, `bloc_test`, `mocktail`.

**Spec:** `docs/superpowers/specs/2026-10-29-duotab-design.md`

## Roadmap

This is the first of four plans; each later one is written after the previous lands, against the code that exists then.

| Plan | Delivers |
|---|---|
| 1 Foundation (this) | spike, app shell, fold gate, vertical-bar navigation, workspace layout, library, Open In, read-only score viewer |
| 2 Playback | DuoTab MIDI writer, native `AVAudioSequencer` engine, transport, tones, practice settings store, cursor, A–B loop, count-in, metronome, pause on close |
| 3 Editor | new song, cursor and fret pad, palette, voices, bar check, bar editing, tempo and time signatures, guitar track management, undo/redo, autosave and the "(DuoTab)" copy |
| 4 Retune and export | retuning, automatic fingering for parts without string/fret data (Plan 1 shows such parts with `crisp_notation`'s default lowest-fret placement), how unplayable notes are saved, `.gp` / MusicXML / PDF export and share sheet |

## Global Constraints

- iOS only; `IPHONEOS_DEPLOYMENT_TARGET = 27.1`, built with Xcode 27.1 (iOS 27.1 SDK).
- Flutter package name `duotab`; bundle identifier `me.withedgar.duotab`; every platform channel is named `me.withedgar.duotab/<name>`.
- `analysis_options.yaml` is copied verbatim from `/Users/eordonez/Code/sideprojects/dreambudget_app/analysis_options.yaml`; `flutter analyze` must report no issues at every commit.
- No LGPL (or GPL) Dart packages.
- All user-facing strings come from `lib/l10n/app_en.arb`. Exact copy fixed by the spec: `Open your iPhone Duo to continue`, `This song has no guitar track`, `Make DuoTab wider to edit`.
- `/Users/eordonez/Desktop/07 Collateral Damage.xml` is licensed: never copy it into the repo. Tests reach it only through the environment variable `DUOTAB_PRIVATE_SAMPLE` and skip when it is unset.
- Native Swift code lives in `ios/Runner/AppDelegate.swift`, as in dreambudget, so no task edits `project.pbxproj` by hand.
- Supported song extensions, lowercase: `.gp3`, `.gp4`, `.gp5`, `.gpx`, `.gp`, `.musicxml`, `.xml`, `.mxl`.

## Review Focus

1. **A malformed or unsupported file in Documents** must show as an unreadable entry in the library; the list still loads and the app does not crash. Test: Task 8 `loader reports FormatException as SongLoadError`, Task 9 `lists a broken file as unreadable`.
2. **A large real file** (1.9 MB, 7 parts) must not freeze the UI while it parses. Test: Task 8 `parses off the main isolate` and the env-gated `loads the private sample`.
3. **Closing and reopening the phone** must keep the selected tab and the open song. Test: Task 5 `keeps app state across close and reopen`.
4. **The vertical bar moving to the other edge** (rotation) must mirror the layout and keep the score centred. Test: Task 7 `mirrors when the bar is on the leading edge`.
5. **Opening a file whose name already exists in Documents** must keep both, never overwrite. Test: Task 10 `uniqueDestination adds a counter before the extension`.

---

### Task 1: Engine spike

Throwaway code on branch `spike/engine`, never merged. Only the report lands on `main`.

**Files:**
- Create (branch only): `spike/engine_probe/` (a scratch Flutter app)
- Create (on `main`): `docs/superpowers/spikes/2026-10-29-engine-spike.md`

**Interfaces:**
- Produces: the report, which later tasks read for the exact `crisp_notation` / `crisp_notation_core` calls and widget parameters. It must answer every question in Step 6.

- [ ] **Step 1: Create the scratch app**

```bash
git switch -c spike/engine
flutter create --platforms=ios --org me.withedgar --project-name engine_probe spike/engine_probe
cd spike/engine_probe && flutter pub add crisp_notation crisp_notation_core path_provider
```

Expected: `flutter pub get` resolves `crisp_notation` and `crisp_notation_core` 0.13.x.

- [ ] **Step 2: Gather test files outside the repo**

Copy the private sample and any other test files into `/Users/eordonez/Code/sideprojects/duotab/test_assets_private/` (gitignored). Ask the owner to export the private sample from Guitar Pro 8 as `.gp`, and as `.gp5` if Guitar Pro 8 offers it. Download the alphaTab test corpus (`test-data/` in github.com/CoderLine/alphaTab) for GP3, GP4, GP5, GPX and multi-voice files, and record its licence in the report.

- [ ] **Step 3: Render check (spec Step 0 checks 1 and 2)**

In the scratch app, load each file with the matching reader (`scoreFromMusicXml` / `multiPartScoreFromMusicXml`, `readMusicXmlFromMxl`, `readGpifFromGp` + `multiPartScoreFromGpif`, `readGpifFromGpx`, `gpToMultiPart`). Show each guitar part with `NotationTabView`, and also build a song in code with 7 and 8 strings, mixed time signatures, a tempo change and four voices. Run on the booted iPhone Duo simulator (`flutter run -d "iPhone Duo"`), take screenshots into `test_assets_private/spike/`, and note in the report, per file, what renders wrong or is missing.

- [ ] **Step 4: Round-trip check (spec check 3)**

Write the code-built song with `multiPartToGpif` + `writeGpFromGpif` to `test_assets_private/spike/roundtrip.gp`. The owner opens it in Guitar Pro 8 and reports what survived: voices 3–4, tunings, time signatures, tempo change, techniques. Also record what `scoreToGpif` does with a note no string can reach.

- [ ] **Step 5: Playback check (spec check 4)**

In the scratch app's `AppDelegate.swift`, add a method channel that loads MIDI bytes into `AVAudioSequencer` with an `AVAudioUnitSampler` loaded from a candidate General MIDI SoundFont, and reports `currentPositionInBeats`. Feed it a minimal format-1 file built from `playbackTimeline` of the private sample's first guitar part (program 30). Check that playback stays in time with a highlight driven by polling position at 60 Hz. Record the SoundFont chosen, its size, its licence, and whether it needs cutting down to the guitar, bass and drum programs to keep the app small.

- [ ] **Step 6: Write the report and decide**

The report answers:
1. Per check (spec Step 0, 1–5): pass, partial (what is missing) or fail.
2. The exact calls and fields for each imported track's name, tuning, string count, MIDI program, percussion flag, and per-note string pins.
3. `NotationTabView`'s constructor parameters, how it wraps a long part into systems, and how it is put in a vertical scroll view.
4. The time to parse the private sample on the simulator.
5. The decision: keep `crisp_notation` (possibly forked), or the spec's fallback that applies.

If the decision is anything other than "keep", stop after this task and bring the report to the owner. Tasks 8 and 11 depend on it.

- [ ] **Step 7: Commit the report to `main`**

```bash
git switch main
git add docs/superpowers/spikes/2026-10-29-engine-spike.md
git commit -m "docs: record engine spike results"
```

---

### Task 2: App scaffold

**Files:**
- Create: Flutter project in the repo root (`pubspec.yaml`, `lib/`, `ios/`, `test/`)
- Create: `analysis_options.yaml` (copied, see Global Constraints), `l10n.yaml`, `lib/l10n/app_en.arb`
- Create: `lib/main.dart`, `lib/app.dart`, `lib/core/dependency_injection.dart`
- Create: `lib/core/design/design_tokens.dart`, `lib/core/design/app_spacing.dart`, `lib/core/design/app_colors.dart`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (deployment target only, via `sed`), `ios/Podfile` (`platform :ios, '27.1'`)
- Test: `test/widget/app_test.dart`

**Interfaces:**
- Produces: `Future<void> setupDependencies()` in `lib/core/dependency_injection.dart` (later tasks add registrations), `final getIt = GetIt.instance`; `class DuoTabApp extends StatelessWidget` in `lib/app.dart` with `home` supplied by later tasks (`const Placeholder()` for now); tokens `Spacing.{xs=4, sm=8, md=16, lg=24, xl=32}`, `AccessibleSizes.minTouchTarget = 48`, `IconSizes.md = 24`, `AppColors.accent = Color(0xFF3D7CFF)`, `AppColors.panel = Color(0xFF1E2128)`, `AppColors.paper = Color(0xFFFBFBF8)`.

- [ ] **Step 1: Generate the project**

```bash
flutter create --platforms=ios --org me.withedgar --project-name duotab .
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 27.1;/' ios/Runner.xcodeproj/project.pbxproj
flutter pub add flutter_bloc get_it provider path_provider intl crisp_notation crisp_notation_core
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev bloc_test mocktail
```

Set `flutter: generate: true` in `pubspec.yaml`. `l10n.yaml` sets `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`. Delete the generated counter app and its test.

- [ ] **Step 2: Write the failing test**

```dart
testWidgets('boots with localized title', (tester) async {
  await tester.pumpWidget(const DuoTabApp(home: SizedBox()));
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.title, 'DuoTab');
  expect(app.supportedLocales, contains(const Locale('en')));
});
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/widget/app_test.dart`
Expected: FAIL (`DuoTabApp` not defined)

- [ ] **Step 4: Implement `DuoTabApp({required Widget home})`, the tokens and `main()`**

`main()` calls `WidgetsFlutterBinding.ensureInitialized()`, `await Bravura.load()`, `await setupDependencies()`, then `runApp`. The theme is dark, with `AppColors.panel` as the surface colour. `app_en.arb` starts with `appTitle: "DuoTab"`.

- [ ] **Step 5: Verify**

Run: `flutter test && flutter analyze && flutter build ios --simulator --debug`
Expected: tests pass, `No issues found!`, `✓ Built build/ios/iphonesimulator/Runner.app`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: scaffold DuoTab Flutter app for iOS 27.1"
```

---

### Task 3: Vertical-bar edge bridge

A port of dreambudget commit `556e8f9`, with the channel renamed.

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `lib/core/duo/vertical_bar_edge_provider.dart`
- Modify: `lib/core/dependency_injection.dart`, `lib/app.dart` (provide it)
- Test: `test/unit/core/duo/vertical_bar_edge_provider_test.dart`

**Interfaces:**
- Produces: `enum VerticalBarEdge { unspecified, leading, trailing }`; `class VerticalBarEdgeProvider extends ChangeNotifier` with `VerticalBarEdgeProvider({Stream<dynamic>? edgeEvents})`, `VerticalBarEdge get edge`, `static VerticalBarEdge edgeOf(BuildContext context)`. Channel `me.withedgar.duotab/vertical_bar_edge`, events `'leading' | 'trailing' | 'unspecified'`.

- [ ] **Step 1: Port the tests**

Copy `dreambudget_app/test/unit/core/vertical_bar_edge_provider_test.dart`, changing the import to `package:duotab/core/duo/vertical_bar_edge_provider.dart`. Its three tests stay as they are: follows reported edges, no notification on an unchanged edge, unknown values and errors map to `unspecified`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/core/duo/vertical_bar_edge_provider_test.dart`
Expected: FAIL (import not found)

- [ ] **Step 3: Port the provider and the Swift `VerticalBarEdgeStreamHandler`**

Copy `dreambudget_app/lib/core/vertical_bar_edge_provider.dart` (replace `ErrorHandler.handleError` with `debugPrint`, since DuoTab has no error tracker) and the handler class plus its registration from `dreambudget_app/ios/Runner/AppDelegate.swift`. Change the channel name. With the 27.1 deployment target, the `#available(iOS 27.1, *)` guards can go.

- [ ] **Step 4: Verify**

Run: `flutter test test/unit/core/duo && flutter analyze && flutter build ios --simulator --debug`
Expected: all pass, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: stream the iPhone Duo vertical bar edge to Flutter"
```

---

### Task 4: Hinge bridge

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `lib/core/duo/hinge_status_provider.dart`
- Modify: `lib/core/dependency_injection.dart`, `lib/app.dart`
- Test: `test/unit/core/duo/hinge_status_provider_test.dart`

**Interfaces:**
- Produces: `enum HingeStatus { unknown, closed, partiallyOpen, fullyOpen, unavailable }`; `class HingeStatusProvider extends ChangeNotifier` with `HingeStatusProvider({Stream<dynamic>? hingeEvents})`, `HingeStatus get status`, `bool get isOpen`, `static bool isOpenOf(BuildContext context)`. Channel `me.withedgar.duotab/hinge_status`, events `'unknown' | 'closed' | 'partiallyOpen' | 'fullyOpen' | 'unavailable'`.
- `isOpen` is `false` only for `closed`. `unknown` and `unavailable` count as open, so the app stays usable where no hinge is reported (the builder's call the spec leaves open).

- [ ] **Step 1: Write the failing tests**

```dart
test('is closed only when the hinge reports closed', () async {
  events..add('fullyOpen')..add('closed')..add('partiallyOpen');
  await pumpEventQueue();
  expect(seen, [true, false, true]); // isOpen after each change
});

test('treats unknown, unavailable, unrecognised values and errors as open', () async {
  events..add('closed')..add('unavailable');
  await pumpEventQueue();
  expect(provider.isOpen, isTrue);
  events..add('closed')..add('sideways');
  await pumpEventQueue();
  expect(provider.status, HingeStatus.unknown);
  events..add('closed')..addError(Exception('channel failed'));
  await pumpEventQueue();
  expect(provider.isOpen, isTrue);
});

test('does not notify when the status is unchanged', () async { /* two 'closed' → 1 notification */ });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/core/duo/hinge_status_provider_test.dart`
Expected: FAIL (import not found)

- [ ] **Step 3: Implement the provider and `HingeStatusStreamHandler` (Swift)**

The provider mirrors `VerticalBarEdgeProvider`'s shape. In `onListen`, the Swift handler adds `UIHingeInteraction { _, update in … }` to `registrar.viewController.view` and sends `update.hinge?.status` mapped to the event strings (`nil` hinge → `'unavailable'`). In `onCancel`, it removes the interaction. Register it in `didInitializeImplicitFlutterEngine` next to the vertical-bar handler.

- [ ] **Step 4: Verify on the simulator**

Run: `flutter test test/unit/core/duo && flutter analyze && flutter run -d "iPhone Duo"`. Add a temporary `debugPrint` in the provider, close and open the device from the simulator's Device Hub, and confirm `closed`, `partiallyOpen` and `fullyOpen` arrive. Remove the print.
Expected: tests pass; the three statuses are logged as the hinge moves.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: stream the iPhone Duo hinge status to Flutter"
```

---

### Task 5: Fold gate and folded screen

**Files:**
- Create: `lib/presentation/shell/fold_gate.dart`, `lib/presentation/shell/folded_screen.dart`
- Modify: `lib/l10n/app_en.arb` (`foldedMessage: "Open your iPhone Duo to continue"`), `lib/main.dart` (`home: FoldGate(child: …)`)
- Test: `test/widget/shell/fold_gate_test.dart`

**Interfaces:**
- Consumes: `HingeStatusProvider` (Task 4).
- Produces: `FoldGate({required Widget child})`, `FoldedScreen()` (placeholder logo: a 64×64 rounded square in `AppColors.accent` with the text `DT`, above `foldedMessage`).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shows the folded screen only while closed', (tester) async {
  // pump FoldGate(child: Text('app')) under a HingeStatusProvider fed by a StreamController
  events.add('closed'); await tester.pump();
  expect(find.text('Open your iPhone Duo to continue'), findsOneWidget);
  expect(find.text('app'), findsNothing); // offstage child is not found by default finders
  events.add('partiallyOpen'); await tester.pump();
  expect(find.text('app'), findsOneWidget);
  expect(find.byType(FoldedScreen), findsNothing);
});

testWidgets('keeps app state across close and reopen', (tester) async {
  // child: a StatefulWidget counter; tap it to 1, close, reopen
  expect(find.text('count: 1'), findsOneWidget);
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/widget/shell/fold_gate_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `FoldGate`**

`FoldGate` is a `Stack`: the child stays mounted inside `Offstage` plus `TickerMode(enabled: false)` while closed, with `FoldedScreen` on top. That keeps the child's state.

- [ ] **Step 4: Verify**

Run: `flutter test test/widget/shell && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: show a folded screen while iPhone Duo is closed"
```

---

### Task 6: App shell and navigation

**Files:**
- Create: `lib/presentation/shell/app_shell.dart`, `lib/presentation/shell/app_destinations.dart`, `lib/presentation/widgets/glass_capsule.dart`, `lib/presentation/widgets/app_navigation_rail.dart`
- Create: `lib/presentation/shell/navigation_cubit.dart`
- Create: `lib/features/settings/settings_page.dart` (title only)
- Modify: `lib/l10n/app_en.arb` (`tabLibrary: "Library"`, `tabEditor: "Editor"`, `tabSettings: "Settings"`, `navigationLabel: "Main navigation"`), `lib/main.dart`
- Test: `test/widget/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `VerticalBarEdgeProvider` (Task 3).
- Produces: `enum AppTab { library, editor, settings }`; `class NavigationCubit extends Cubit<AppTab>` with `void select(AppTab tab)`; `AppShell({required Widget Function(AppTab) pageFor})`. `GlassCapsule` and `AppNavigationRail` are ported from dreambudget (`withOpacityValue` becomes `withValues(alpha:)`, `AppColors.transferBlue` becomes `AppColors.accent`).
- The rail is drawn with the bar's width and centred in it, placed on the side `VerticalBarEdge` gives (mapped through text direction, as in `VerticalBarNavigationShell`). With `unspecified`, a bottom `NavigationBar` is shown instead.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('puts the tab capsule in a trailing vertical bar', (tester) async {
  // MediaQuery(size: 890x626, padding: EdgeInsets.only(right: 46)), edge 'trailing'
  final rail = tester.getRect(find.byType(AppNavigationRail));
  expect(rail.center.dx, closeTo(890 - 46 / 2, 0.5));
  expect(find.byType(NavigationBar), findsNothing);
});
testWidgets('uses a bottom navigation bar when there is no vertical bar', …);
testWidgets('switches pages from the capsule', (tester) async {
  await tester.tap(find.byTooltip('Settings')); await tester.pump();
  expect(find.byType(SettingsPage), findsOneWidget);
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/widget/shell/app_shell_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `AppShell`, `NavigationCubit` and the ports**

The page fills the whole screen, so content can run under the bar (Task 7 handles the insets). The rail floats over it, bottom-aligned with `padding.bottom + Spacing.sm`, as in dreambudget.

- [ ] **Step 4: Verify**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add tab navigation in the iPhone Duo vertical bar"
```

---

### Task 7: Workspace layout

Implements the approved option A v2 mockup (`.superpowers/brainstorm/75036-1793277125/content/editor-layout-v2.html`).

**Files:**
- Create: `lib/presentation/workspace/workspace_layout.dart`
- Modify: `lib/l10n/app_en.arb` (`widerToEdit: "Make DuoTab wider to edit"`)
- Test: `test/widget/workspace/workspace_layout_test.dart`

**Interfaces:**
- Consumes: `VerticalBarEdgeProvider.edgeOf`.
- Produces: `WorkspaceLayout({required Widget palette, required Widget score, required Widget trackPanel, Widget? transport})`; constants `kSidePanelWidth = 220.0` (a panel's full width, including any part under the bar) and `kThreeColumnMinWidth = 720.0`; `static bool isCollapsed(BuildContext context)`.
- Layout rule: both side panels are `kSidePanelWidth` wide and painted `AppColors.panel` edge to edge. The panel on the bar's side pads its content by the bar's safe-area inset on that side; the other panel pads by its own safe-area inset. The score fills the middle, so it is centred on the screen. Below `kThreeColumnMinWidth`, only `score` (and `transport`) show, with a `widerToEdit` banner above the score.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('centres the score on the full screen with a trailing bar', (tester) async {
  // 890x626, padding right 46, edge trailing
  final score = tester.getRect(find.byKey(const Key('score')));
  expect(score.left, 220); expect(score.right, 670);
  expect(score.center.dx, 445);
  final panelContent = tester.getRect(find.byKey(const Key('trackPanel')));
  expect(panelContent.right, lessThanOrEqualTo(890 - 46));
});
testWidgets('mirrors when the bar is on the leading edge', (tester) async {
  // padding left 46, edge leading
  final palette = tester.getRect(find.byKey(const Key('palette')));
  expect(palette.left, greaterThanOrEqualTo(46));
  expect(tester.getRect(find.byKey(const Key('score'))).center.dx, 445);
});
testWidgets('collapses to the score below the three-column width', (tester) async {
  // width 600
  expect(find.byKey(const Key('palette')), findsNothing);
  expect(find.text('Make DuoTab wider to edit'), findsOneWidget);
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/widget/workspace/workspace_layout_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `WorkspaceLayout`**

- [ ] **Step 4: Verify**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: three-column workspace centred on the iPhone Duo screen"
```

---

### Task 8: Song model and loader

**Files:**
- Create: `lib/features/song/song.dart`, `lib/features/song/track_kind.dart`, `lib/features/song/song_loader.dart`
- Create: `test/fixtures/two_guitars_and_drums.musicxml` (authored for this repo: two 6-string guitar parts with `<staff-details>` tuning and `<technical><string>/<fret>`, a percussion part on MIDI channel 10, 4 bars, 4/4 then 7/8), `test/fixtures/broken.gp5` (20 random bytes)
- Test: `test/unit/features/song/track_kind_test.dart`, `test/unit/features/song/song_loader_test.dart`

**Interfaces:**
- Consumes: the spike report's answers 2 and 4 (Task 1).
- Produces:
  - `enum TrackKind { guitar, drums, other }` and `TrackKind classifyTrack({required bool hasStrings, required bool isPercussion, int? midiProgram})`: percussion → drums; strings in the file, or a program in 25–32 → guitar; anything else → other.
  - `class SongTrack { final int index; final String name; final TrackKind kind; final Tuning? tuning; final int? stringCount; final int? midiProgram; final Score score; }`: `tuning` and `stringCount` are null for tracks without strings
  - `class Song { final String path; final String title; final List<SongTrack> tracks; List<SongTrack> get guitarTracks; }`
  - `sealed class SongLoadResult`, `SongLoaded(Song song)`, `SongLoadError(String path, String reason)`
  - `class SongLoader { Future<SongLoadResult> load(String path); }`: picks the reader by extension (the Global Constraints list); parsing runs in `Isolate.run`; any `FormatException`, `ArgumentError` or unknown extension becomes `SongLoadError`. The title comes from the file, falling back to the file name without its extension.

- [ ] **Step 1: Write the failing tests**

```dart
test('classifies tracks', () {
  expect(classifyTrack(hasStrings: true, isPercussion: false), TrackKind.guitar);
  expect(classifyTrack(hasStrings: false, isPercussion: false, midiProgram: 30), TrackKind.guitar);
  expect(classifyTrack(hasStrings: false, isPercussion: false, midiProgram: 34), TrackKind.other);
  expect(classifyTrack(hasStrings: true, isPercussion: true), TrackKind.drums);
});

test('loads the fixture with two guitar tracks and drums', () async {
  final r = await SongLoader().load('test/fixtures/two_guitars_and_drums.musicxml') as SongLoaded;
  expect(r.song.tracks.map((t) => t.kind), [TrackKind.guitar, TrackKind.guitar, TrackKind.drums]);
  expect(r.song.guitarTracks.first.stringCount, 6);
});

test('loader reports FormatException as SongLoadError', () async {
  expect(await SongLoader().load('test/fixtures/broken.gp5'), isA<SongLoadError>());
});

test('parses off the main isolate', () async { /* a loader built with a spy runner records that Isolate.run was used */ });

test('loads the private sample', () async {
  final path = Platform.environment['DUOTAB_PRIVATE_SAMPLE'];
  final r = await SongLoader().load(path!) as SongLoaded;
  expect(r.song.title, 'Collateral Damage');
  expect(r.song.guitarTracks, hasLength(7));
  expect(r.song.guitarTracks.first.stringCount, 6);
}, skip: Platform.environment['DUOTAB_PRIVATE_SAMPLE'] == null);
```

For the spy, `SongLoader` takes an optional `Future<T> Function<T>(FutureOr<T> Function())` runner that defaults to `Isolate.run`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/song`
Expected: FAIL

- [ ] **Step 3: Implement `classifyTrack`, the types and `SongLoader`**

- [ ] **Step 4: Verify, including the private sample**

Run: `DUOTAB_PRIVATE_SAMPLE="/Users/eordonez/Desktop/07 Collateral Damage.xml" flutter test test/unit/features/song && flutter analyze`
Expected: all pass, the private-sample test included.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: load Guitar Pro and MusicXML songs into DuoTab's model"
```

---

### Task 9: Song library

**Files:**
- Create: `lib/features/library/song_summary.dart`, `lib/features/library/library_cubit.dart`, `lib/features/library/library_page.dart`
- Modify: `ios/Runner/Info.plist` (`UIFileSharingEnabled` = true, `LSSupportsOpeningDocumentsInPlace` = true), `lib/l10n/app_en.arb` (`libraryEmpty: "Add Guitar Pro or MusicXML files in the Files app, under On My iPhone › DuoTab"`, `unreadableFile: "Can't open this file"`, `newSong: "New song"`, `stringsCount: "{count} strings"`)
- Test: `test/unit/features/library/library_cubit_test.dart`, `test/widget/library/library_page_test.dart`

**Interfaces:**
- Consumes: `SongLoader` (Task 8).
- Produces: `class SongSummary { final String path; final String title; final String? tuningLabel; final int? stringCount; final bool readable; }` (`tuningLabel` is the open strings low to high, e.g. `E♭ A♭ D♭ G♭ B♭ E♭`, taken from the first guitar track); `class LibraryCubit extends Cubit<LibraryState>` with `LibraryCubit({required Directory documents, required SongLoader loader})`, `Future<void> refresh()`; `LibraryState { final bool loading; final List<SongSummary> songs; }` sorted by title; `LibraryPage({required void Function(String path) onOpen})`. The "New song" button is shown disabled until Plan 3.
- Summaries are cached in memory by path and modification time, so `refresh()` re-parses only changed files.

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<LibraryCubit, LibraryState>('lists supported files sorted by title',
  // temp dir with b.musicxml (fixture copy), a.gp5 (broken), notes.txt
  expect: () => [isLoading, hasSongs(['a', 'b'])]);   // notes.txt ignored
test('lists a broken file as unreadable', …);           // a.gp5 → readable false
test('re-parses only files that changed', …);           // loader spy call count
testWidgets('shows title, tuning and string count', …); // 'E A D G B E', '6 strings'
testWidgets('shows the empty-library hint', …);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/library test/widget/library`
Expected: FAIL

- [ ] **Step 3: Implement**

`main()` resolves Documents with `getApplicationDocumentsDirectory()` and registers `LibraryCubit` in `setupDependencies()`. The library refreshes when the app returns to the foreground (`AppLifecycleListener.onResume`), so files added in the Files app appear.

- [ ] **Step 4: Verify**

Run: `flutter test && flutter analyze`. Then on the simulator, copy the private sample into the app's Documents with `cp "/Users/eordonez/Desktop/07 Collateral Damage.xml" "$(xcrun simctl get_app_container booted me.withedgar.duotab data)/Documents/"` and relaunch.
Expected: tests pass; the library shows "Collateral Damage", `E♭ A♭ D♭ G♭ B♭ E♭`, "6 strings", and the Files app lists the DuoTab folder.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: list songs from the DuoTab Files folder"
```

---

### Task 10: Open files from other apps

**Files:**
- Modify: `ios/Runner/Info.plist` (`CFBundleDocumentTypes` for the supported extensions; `UTImportedTypeDeclarations` for `com.arobas-music.guitarpro.gp3`…`.gp`, `org.musicxml.xml`, `com.recordare.musicxml.mxl`, each conforming to `public.data`; exact identifiers to confirm against the ones Guitar Pro 8 declares in its own `Info.plist` on the Mac)
- Modify: `ios/Runner/AppDelegate.swift` (an `IncomingFilesStreamHandler`; the scene delegate's `scene(_:openURLContexts:)` and the launch `connectionOptions.urlContexts` copy each URL, inside `startAccessingSecurityScopedResource`, to `Caches/incoming/<uuid>/<original name>`, then send that path)
- Create: `lib/features/import/incoming_files_provider.dart`, `lib/features/import/unique_destination.dart`
- Test: `test/unit/features/import/unique_destination_test.dart`, `test/unit/features/import/incoming_files_provider_test.dart`

**Interfaces:**
- Consumes: `LibraryCubit.refresh()` (Task 9), `NavigationCubit.select` (Task 6), `ScoreCubit.open` (Task 11; wire it in Task 11).
- Produces: `File uniqueDestination(Directory dir, String fileName)`; `class IncomingFilesProvider` with `IncomingFilesProvider({Stream<dynamic>? events, required Directory documents, required Future<void> Function(String path) onImported})`. It moves each incoming file into Documents at `uniqueDestination`, deletes the staging folder, then calls `onImported` with the final path. Channel `me.withedgar.duotab/incoming_files`.

- [ ] **Step 1: Write the failing tests**

```dart
test('uniqueDestination adds a counter before the extension', () {
  // dir contains '07 Collateral Damage.xml' and '07 Collateral Damage (2).xml'
  expect(p.basename(uniqueDestination(dir, '07 Collateral Damage.xml').path),
      '07 Collateral Damage (3).xml');
  expect(p.basename(uniqueDestination(dir, 'new.gp').path), 'new.gp');
});
test('moves an incoming file into Documents and reports it', () async {
  // staged file in tmp/incoming/x/song.gp → documents/song.gp exists, staging dir gone, onImported called once
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/import`
Expected: FAIL

- [ ] **Step 3: Implement the Dart side, then the Swift handler and the plist entries**

- [ ] **Step 4: Verify on the simulator**

Run: `flutter test && flutter analyze && flutter run -d "iPhone Duo"`. In the simulator's Files app, put a copy of the fixture into "On My iPhone" (outside DuoTab), long-press it, choose Share › DuoTab.
Expected: DuoTab opens and the file appears in the library. Sharing the same file again adds `(2)`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: open Guitar Pro and MusicXML files shared from other apps"
```

---

### Task 11: Read-only score viewer

**Files:**
- Create: `lib/features/score/score_cubit.dart`, `lib/features/score/score_page.dart`, `lib/features/score/track_panel.dart`
- Modify: `lib/main.dart` (Editor tab → `ScorePage`; library `onOpen` → `ScoreCubit.open` + switch to Editor; `IncomingFilesProvider.onImported` → refresh, open, switch), `lib/l10n/app_en.arb` (`noGuitarTrack: "This song has no guitar track"`, `noSongOpen: "Open a song from the library"`, `tracksHeading: "Tracks"`)
- Test: `test/unit/features/score/score_cubit_test.dart`, `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes: `SongLoader`, `Song`, `SongTrack` (Task 8); `WorkspaceLayout` (Task 7); `NotationTabView` with the parameters recorded in the spike report (answer 3).
- Produces: `class ScoreCubit extends Cubit<ScoreState>` with `Future<void> open(String path)`, `void selectTrack(int trackIndex)`; `ScoreState { final Song? song; final int? selectedTrackIndex; final bool loading; final String? error; }`. Opening selects the first guitar track; a song with none leaves `selectedTrackIndex` null.
- `ScorePage` fills `WorkspaceLayout`. `score` is the selected track as notation over tab in a vertical scroll view, with the song title above it. `trackPanel` lists `song.guitarTracks` by name with the selected one highlighted. `palette` is an empty panel until Plan 3.

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<ScoreCubit, ScoreState>('opening selects the first guitar track', …);   // fixture → selectedTrackIndex 0
blocTest<ScoreCubit, ScoreState>('a song without guitar tracks selects none', …); // drums-only fixture variant
testWidgets('lists only guitar tracks and switches between them', (tester) async {
  expect(find.text('Guitar 1'), findsOneWidget);
  expect(find.text('Drums'), findsNothing);
  await tester.tap(find.text('Guitar 2')); await tester.pump();
  expect(cubit.state.selectedTrackIndex, 1);
});
testWidgets('says when a song has no guitar track', …);  // 'This song has no guitar track'
testWidgets('asks to open a song when none is open', …); // 'Open a song from the library'
```

Add `test/fixtures/drums_only.musicxml` (one percussion part, 2 bars) for the no-guitar cases.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/score test/widget/score`
Expected: FAIL

- [ ] **Step 3: Implement `ScoreCubit`, `ScorePage` and `TrackPanel`**

- [ ] **Step 4: Verify the whole plan on the simulator**

Run: `flutter test && flutter analyze && flutter run -d "iPhone Duo"`, then:
1. The library shows Collateral Damage. Tap it: the Editor tab shows "Guitar 1" as notation over E♭-standard tab, centred, with Guitar 1–7 in the right panel under the vertical bar.
2. Tap "Guitar 3": the score switches.
3. Close the device in Device Hub: the folded screen appears. Reopen it: the same song and track are still shown.
4. Rotate so the bar moves to the left: the layout mirrors, and the score stays centred.

Save screenshots of 1, 3 and 4 to `test_assets_private/plan1/`.
Expected: all four behave as described.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: show guitar tracks as notation over tab"
```
