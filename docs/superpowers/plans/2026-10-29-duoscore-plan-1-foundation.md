# DuoScore Plan 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove alphaTab inside a web view on iPhone Duo, then ship an app that runs only unfolded, lists the songs in its Files folder, accepts files opened from other apps, and shows any guitar track as notation over tab.

**Architecture:** Flutter app (iOS only) structured like dreambudget: cubits for feature state, `get_it` for wiring, `ChangeNotifier` providers fed by native `EventChannel`s for the vertical-bar edge and the hinge. Songs live in `engine/`, a TypeScript package around alphaTab that runs in one long-lived `WKWebView` and talks to Dart over a JSON message bridge; Dart only sees song summaries.

**Tech Stack:** Flutter 3.47.8, Dart 3, Swift (UIKit, iOS 27.1 SDK), `webview_flutter`, `flutter_bloc`, `get_it`, `provider`, `path_provider`, `flutter_localizations` + `intl`, `bloc_test`, `mocktail`; TypeScript, `@coderline/alphatab` 1.6.1, esbuild, vitest, Node 26.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`

## Roadmap

This is the first of four plans; each later one is written after the previous lands, against the code that exists then.

| Plan | Delivers |
|---|---|
| 1 Foundation (this) | engine spikes, app shell, fold gate, vertical-bar navigation, workspace layout, engine package and bridge, library, Open In, read-only score view |
| 2 Playback | engine player commands, transport, tones, practice settings store, cursor, A–B loop, count-in, metronome, pause on close, the track drawer (mute/solo, bar overview grid) replacing Plan 1's right-hand track list, the track information panel, the licence screen (alphaTab, Bravura, Sonivox) in Settings |
| 3 Editor | new song, tap-to-cursor and fret pad, palette, voices, bar check, bar editing, tempo and time signatures, guitar track management, undo/redo, autosave and the "(DuoScore)" copy |
| 4 Retune and export | retuning, automatic fingering for parts without string/fret data, `.gp` and PDF export, share sheet |

## Global Constraints

- iOS only; `IPHONEOS_DEPLOYMENT_TARGET = 27.1`, built with Xcode 27.1 (iOS 27.1 SDK).
- Flutter package name `duoscore`; bundle identifier `dev.edbrsk.duoscore`; every platform channel is named `dev.edbrsk.duoscore/<name>`.
- `analysis_options.yaml` is copied verbatim from `/Users/eordonez/Code/sideprojects/dreambudget_app/analysis_options.yaml`; `flutter analyze` must report no issues at every commit.
- No LGPL (or GPL) Dart packages.
- `@coderline/alphatab` is pinned to exactly `1.6.1` in `engine/package.json` and shipped unmodified.
- The engine builds with `npm --prefix engine run build` into `assets/engine/`, which is git-ignored; `flutter build` and `flutter run` need it built first. `npm --prefix engine test` runs the engine's tests.
- Engine message types are declared once in `engine/src/protocol.ts` and mirrored in `lib/engine/protocol.dart`; a change to one changes the other in the same commit.
- All user-facing strings come from `lib/l10n/app_en.arb`. Exact copy fixed by the spec: `Open your iPhone Duo to continue`, `This song has no guitar track`, `Make DuoScore wider to edit`.
- The owner's songs (`/Users/eordonez/Desktop/2. Guitar Pro Files/`) and the alphaTab test corpus are never copied into the repo. Tests reach the primary song only through the environment variable `DUOSCORE_PRIVATE_SAMPLE` (`/Users/eordonez/Desktop/2. Guitar Pro Files/07 Collateral Damage.gp`) and skip when it is unset.
- Native Swift code lives in `ios/Runner/AppDelegate.swift`, as in dreambudget, so no task edits `project.pbxproj` by hand.
- Supported song extensions, lowercase: `.gp3`, `.gp4`, `.gp5`, `.gpx`, `.gp`, `.musicxml`, `.xml`, `.mxl`.

## Review Focus

1. **A malformed or unsupported file in Documents** must show as an unreadable entry in the library; the list still loads and the app does not crash. Tests: Task 9 `summarize reports a broken file as an error`, Task 11 `lists a broken file as unreadable`.
2. **The engine never answering** (web view not loaded yet, page crashed, slow file) must fail the request after a timeout, not hang the screen that asked. Test: Task 10 `times out a request the engine never answers`.
3. **Closing and reopening the phone** must keep the selected tab and the open song. Test: Task 6 `keeps app state across close and reopen`.
4. **The vertical bar moving to the other edge** (rotation) must mirror the layout and keep the score centred. Test: Task 8 `mirrors when the bar is on the leading edge`.
5. **Opening a file whose name already exists in Documents** must keep both, never overwrite. Test: Task 12 `uniqueDestination adds a counter before the extension`.

---

### Task 1: Engine spike (Step 0a) — done

Completed: `docs/superpowers/spikes/2026-10-29-engine-spike.md`, commits `06acd90` and `2d42ff9`. alphaTab chosen; the owner confirmed Guitar Pro 8 opens alphaTab's `.gp` export.

---

### Task 2: Web view spike (Step 0b)

Throwaway code on branch `spike/engine`, never merged. Only the report lands on `plan-1-foundation`.

**Files:**
- Create (branch only): `spike/webview_probe/` (a scratch Flutter app with `webview_flutter`, and a static page that loads alphaTab)
- Modify (on `plan-1-foundation`): `docs/superpowers/spikes/2026-10-29-engine-spike.md` (add a "Step 0b" section)

**Interfaces:**
- Produces: the report section, answering spec Step 0b checks 1–5. Tasks 9, 10 and 13 read it for: how alphaTab's module, worker, worklet, font and SoundFont are located (settings and URLs that worked); file:// versus the loopback server; load and render time; bridge round-trip time.

- [ ] **Step 1: Build the probe**

The scratch app starts a `dart:io` `HttpServer` on `127.0.0.1:0` serving a folder that holds `index.html`, alphaTab's `dist/` (module, worker, worklet, `font/`, `soundfont/`), and the private sample. It loads `http://127.0.0.1:<port>/index.html` in a `WebViewWidget`. The page imports `alphaTab.mjs` as an ES module, creates `new AlphaTabApi(div, settings)` with `display.staveProfile = ScoreTab`, `core.fontDirectory`, `player.playerMode = EnabledSynthesizer`, `player.soundFont` pointing at `sonivox.sf2`, loads the song by URL, renders only track 0, and posts timings and errors through a `JavaScriptChannel` named `DuoScore`. Add a Play button on the page.

- [ ] **Step 2: Run on the iPhone Duo simulator and check**

Run: `flutter run -d "iPhone Duo"` from `spike/webview_probe`.
Expected, recorded in the report with screenshots in `test_assets_private/spike/`: notation over tab wrapped into lines (check 1); Play sounds in time with the cursor moving (check 2, owner listens); time from page load to first render (check 4); round-trip time of a `ping` from Dart to the page and back (check 5).

- [ ] **Step 3: Try `file://` (check 3)**

Load the same page with `loadFile` from the app bundle and record whether the worker, the worklet, the font and the SoundFont load.
Expected: either it works (the report says the server can serve Documents only) or it fails with the errors recorded (the server stays).

- [ ] **Step 4: Commit the report section**

```bash
git switch plan-1-foundation
git add docs/superpowers/spikes/2026-10-29-engine-spike.md
git commit -m "docs: record web view spike results"
```

If alphaTab cannot draw or play inside the web view, stop and bring the report to the owner.

---

### Task 3: App scaffold

**Files:**
- Create: Flutter project in the repo root (`pubspec.yaml`, `lib/`, `ios/`, `test/`)
- Create: `analysis_options.yaml` (copied, see Global Constraints), `l10n.yaml`, `lib/l10n/app_en.arb`
- Create: `lib/main.dart`, `lib/app.dart`, `lib/core/dependency_injection.dart`
- Create: `lib/core/design/design_tokens.dart`, `lib/core/design/app_spacing.dart`, `lib/core/design/app_colors.dart`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (deployment target only, via `sed`), `ios/Podfile` (`platform :ios, '27.1'`), `.gitignore` (add `assets/engine/`, `engine/node_modules/`)
- Test: `test/widget/app_test.dart`

**Interfaces:**
- Produces: `Future<void> setupDependencies()` in `lib/core/dependency_injection.dart` (later tasks add registrations), `final getIt = GetIt.instance`; `class DuoScoreApp extends StatelessWidget` in `lib/app.dart` with a `home` parameter; tokens `Spacing.{xs=4, sm=8, md=16, lg=24, xl=32}`, `AccessibleSizes.minTouchTarget = 48`, `IconSizes.md = 24`, `AppColors.accent = Color(0xFF3D7CFF)`, `AppColors.panel = Color(0xFF1E2128)`, `AppColors.paper = Color(0xFFFBFBF8)`.

- [ ] **Step 1: Generate the project**

```bash
flutter create --platforms=ios --org dev.edbrsk --project-name duoscore .
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 27.1;/' ios/Runner.xcodeproj/project.pbxproj
flutter pub add flutter_bloc get_it provider path_provider path intl webview_flutter
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev bloc_test mocktail
```

Set `flutter: generate: true` in `pubspec.yaml`. `l10n.yaml` sets `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`. Delete the generated counter app and its test.

- [ ] **Step 2: Write the failing test**

```dart
testWidgets('boots with localized title', (tester) async {
  await tester.pumpWidget(const DuoScoreApp(home: SizedBox()));
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  expect(app.title, 'DuoScore');
  expect(app.supportedLocales, contains(const Locale('en')));
});
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/widget/app_test.dart`
Expected: FAIL (`DuoScoreApp` not defined)

- [ ] **Step 4: Implement `DuoScoreApp({required Widget home})`, the tokens and `main()`**

`main()` calls `WidgetsFlutterBinding.ensureInitialized()`, `await setupDependencies()`, then `runApp`. The theme is dark, with `AppColors.panel` as the surface colour. `app_en.arb` starts with `appTitle: "DuoScore"`.

- [ ] **Step 5: Verify**

Run: `flutter test && flutter analyze && flutter build ios --simulator --debug`
Expected: tests pass, `No issues found!`, `✓ Built build/ios/iphonesimulator/Runner.app`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: scaffold DuoScore Flutter app for iOS 27.1"
```

---

### Task 4: Vertical-bar edge bridge

A port of dreambudget commit `556e8f9`, with the channel renamed.

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `lib/core/duo/vertical_bar_edge_provider.dart`
- Modify: `lib/core/dependency_injection.dart`, `lib/app.dart` (provide it)
- Test: `test/unit/core/duo/vertical_bar_edge_provider_test.dart`

**Interfaces:**
- Produces: `enum VerticalBarEdge { unspecified, leading, trailing }`; `class VerticalBarEdgeProvider extends ChangeNotifier` with `VerticalBarEdgeProvider({Stream<dynamic>? edgeEvents})`, `VerticalBarEdge get edge`, `static VerticalBarEdge edgeOf(BuildContext context)`. Channel `dev.edbrsk.duoscore/vertical_bar_edge`, events `'leading' | 'trailing' | 'unspecified'`.

- [ ] **Step 1: Port the tests**

Copy `dreambudget_app/test/unit/core/vertical_bar_edge_provider_test.dart`, changing the import to `package:duoscore/core/duo/vertical_bar_edge_provider.dart`. Its three tests stay as they are: follows reported edges, no notification on an unchanged edge, unknown values and errors map to `unspecified`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/core/duo/vertical_bar_edge_provider_test.dart`
Expected: FAIL (import not found)

- [ ] **Step 3: Port the provider and the Swift `VerticalBarEdgeStreamHandler`**

Copy `dreambudget_app/lib/core/vertical_bar_edge_provider.dart` (replace `ErrorHandler.handleError` with `debugPrint`, since DuoScore has no error tracker) and the handler class plus its registration from `dreambudget_app/ios/Runner/AppDelegate.swift`. Change the channel name. With the 27.1 deployment target, the `#available(iOS 27.1, *)` guards can go.

- [ ] **Step 4: Verify**

Run: `flutter test test/unit/core/duo && flutter analyze && flutter build ios --simulator --debug`
Expected: all pass, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: stream the iPhone Duo vertical bar edge to Flutter"
```

---

### Task 5: Hinge bridge

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Create: `lib/core/duo/hinge_status_provider.dart`
- Modify: `lib/core/dependency_injection.dart`, `lib/app.dart`
- Test: `test/unit/core/duo/hinge_status_provider_test.dart`

**Interfaces:**
- Produces: `enum HingeStatus { unknown, closed, partiallyOpen, fullyOpen, unavailable }`; `class HingeStatusProvider extends ChangeNotifier` with `HingeStatusProvider({Stream<dynamic>? hingeEvents})`, `HingeStatus get status`, `bool get isOpen`, `static bool isOpenOf(BuildContext context)`. Channel `dev.edbrsk.duoscore/hinge_status`, events `'unknown' | 'closed' | 'partiallyOpen' | 'fullyOpen' | 'unavailable'`.
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

### Task 6: Fold gate and folded screen

**Files:**
- Create: `lib/presentation/shell/fold_gate.dart`, `lib/presentation/shell/folded_screen.dart`
- Modify: `lib/l10n/app_en.arb` (`foldedMessage: "Open your iPhone Duo to continue"`), `lib/main.dart` (`home: FoldGate(child: …)`)
- Test: `test/widget/shell/fold_gate_test.dart`

**Interfaces:**
- Consumes: `HingeStatusProvider` (Task 5).
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

`FoldGate` is a `Stack`: the child stays mounted inside `Offstage` plus `TickerMode(enabled: false)` while closed, with `FoldedScreen` on top. That keeps the child's state, and it keeps the engine's web view (Task 10) alive.

- [ ] **Step 4: Verify**

Run: `flutter test test/widget/shell && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: show a folded screen while iPhone Duo is closed"
```

---

### Task 7: App shell and navigation

**Files:**
- Create: `lib/presentation/shell/app_shell.dart`, `lib/presentation/shell/app_destinations.dart`, `lib/presentation/widgets/glass_capsule.dart`, `lib/presentation/widgets/app_navigation_rail.dart`
- Create: `lib/presentation/shell/navigation_cubit.dart`
- Create: `lib/features/settings/settings_page.dart` (title only)
- Modify: `lib/l10n/app_en.arb` (`tabLibrary: "Library"`, `tabEditor: "Editor"`, `tabSettings: "Settings"`, `navigationLabel: "Main navigation"`), `lib/main.dart`
- Test: `test/widget/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `VerticalBarEdgeProvider` (Task 4).
- Produces: `enum AppTab { library, editor, settings }`; `class NavigationCubit extends Cubit<AppTab>` with `void select(AppTab tab)`; `AppShell({required Widget Function(AppTab) pageFor})`. `GlassCapsule` and `AppNavigationRail` are ported from dreambudget (`withOpacityValue` becomes `withValues(alpha:)`, `AppColors.transferBlue` becomes `AppColors.accent`).
- The rail is drawn with the bar's width and centred in it, placed on the side `VerticalBarEdge` gives (mapped through text direction, as in `VerticalBarNavigationShell`). With `unspecified`, a bottom `NavigationBar` is shown instead.
- Pages are kept alive across tab switches (an `IndexedStack`), so the Editor's web view is never torn down.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('puts the tab capsule in a trailing vertical bar', (tester) async {
  // MediaQuery(size: 890x626, padding: EdgeInsets.only(right: 46)), edge 'trailing'
  final rail = tester.getRect(find.byType(AppNavigationRail));
  expect(rail.center.dx, closeTo(890 - 46 / 2, 0.5));
  expect(find.byType(NavigationBar), findsNothing);
});
testWidgets('uses a bottom navigation bar when there is no vertical bar', …);
testWidgets('switches pages from the capsule and keeps them alive', (tester) async {
  await tester.tap(find.byTooltip('Settings')); await tester.pump();
  expect(find.byType(SettingsPage), findsOneWidget);
  // a stateful page under Library keeps its counter after switching back
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/widget/shell/app_shell_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement `AppShell`, `NavigationCubit` and the ports**

The page fills the whole screen, so content can run under the bar (Task 8 handles the insets). The rail floats over it, bottom-aligned with `padding.bottom + Spacing.sm`, as in dreambudget.

- [ ] **Step 4: Verify**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add tab navigation in the iPhone Duo vertical bar"
```

---

### Task 8: Workspace layout

Implements the approved option A v2 mockup (`.superpowers/brainstorm/75036-1793277125/content/editor-layout-v2.html`).

**Files:**
- Create: `lib/presentation/workspace/workspace_layout.dart`
- Modify: `lib/l10n/app_en.arb` (`widerToEdit: "Make DuoScore wider to edit"`)
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
  expect(find.text('Make DuoScore wider to edit'), findsOneWidget);
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

### Task 9: Engine package

**Files:**
- Create: `engine/package.json` (scripts `build`, `test`; dependency `@coderline/alphatab` `1.6.1` exact; dev dependencies `typescript`, `esbuild`, `vitest`), `engine/tsconfig.json`, `engine/build.mjs`
- Create: `engine/src/protocol.ts`, `engine/src/summary.ts`, `engine/src/track_kind.ts`, `engine/src/main.ts`, `engine/index.html`
- Test: `engine/test/track_kind.test.ts`, `engine/test/summary.test.ts`, `engine/test/fixtures.ts` (alphaTex sources and a helper that turns one into `.gp` bytes with `Gp7Exporter`)

**Interfaces:**
- Consumes: the Task 2 report for the alphaTab settings and asset URLs that work in the web view.
- Produces, in `protocol.ts`:
  - `type Request = { id: number; type: 'ping' | 'summarize' | 'open' | 'renderTrack'; payload: unknown }`, `type Reply = { id: number; ok: true; payload: unknown } | { id: number; ok: false; error: string }`, `type EngineEvent = { event: 'ready' | 'rendered' | 'error'; payload: unknown }`
  - payloads: `summarize { path: string }` → `SongSummary`; `open { path: string }` → `SongSummary`; `renderTrack { index: number }` → `{}` (then a `rendered` event)
  - `type TrackKind = 'guitar' | 'drums' | 'other'`; `type TrackSummary = { index: number; name: string; kind: TrackKind; stringCount: number | null; tuning: number[] | null; midiProgram: number }` (tuning = MIDI numbers, top string first; `midiProgram` 0-based as alphaTab stores it); `type SongSummary = { title: string; tracks: TrackSummary[] }`
- Produces: `classifyTrack(t: { isPercussion: boolean; stringCount: number; midiProgram: number }): TrackKind` (percussion → drums; strings > 0 or a program 24–31 (0-based guitar family) → guitar; else other); `summarize(bytes: Uint8Array, fileName: string): SongSummary` (title falls back to the file name without its extension); `main.ts` installs `window.duoscore = { handle(json: string): void }`, answers through `window.webkit.messageHandlers.DuoScore.postMessage` (the channel `webview_flutter` creates), and posts `ready` once alphaTab is set up. `open` loads the song into the single `AlphaTabApi`; `renderTrack` renders only that track with `staveProfile = ScoreTab`.
- `build.mjs` bundles `src/main.ts` to `../assets/engine/engine.js` with alphaTab left as an external ES module, and copies `index.html` and alphaTab's `dist/` files the Task 2 report names into `../assets/engine/`.

- [ ] **Step 1: Set up the package**

```bash
mkdir -p engine && cd engine && npm init -y
npm install --save-exact @coderline/alphatab@1.6.1
npm install --save-dev typescript esbuild vitest
```

- [ ] **Step 2: Write the failing tests**

```ts
test('classifies tracks', () => {
  expect(classifyTrack({ isPercussion: true, stringCount: 6, midiProgram: 0 })).toBe('drums');
  expect(classifyTrack({ isPercussion: false, stringCount: 7, midiProgram: 0 })).toBe('guitar');
  expect(classifyTrack({ isPercussion: false, stringCount: 0, midiProgram: 29 })).toBe('guitar');
  expect(classifyTrack({ isPercussion: false, stringCount: 0, midiProgram: 33 })).toBe('other');
});

test('summarizes a generated song with two guitars and drums', () => {
  // fixtures.ts: alphaTex with a 6-string guitar (program 29), a 7-string guitar, and a percussion track
  const s = summarize(gpBytes(twoGuitarsAndDrums), 'Fixture.gp');
  expect(s.tracks.map((t) => t.kind)).toEqual(['guitar', 'guitar', 'drums']);
  expect(s.tracks[1].stringCount).toBe(7);
  expect(s.tracks[0].midiProgram).toBe(29);
});

test('summarize reports a broken file as an error', () => {
  expect(() => summarize(new Uint8Array(20), 'broken.gp5')).toThrow();
});

test.skipIf(!process.env.DUOSCORE_PRIVATE_SAMPLE)('summarizes the private sample', () => {
  const s = summarize(new Uint8Array(readFileSync(process.env.DUOSCORE_PRIVATE_SAMPLE!)), '07 Collateral Damage.gp');
  expect(s.tracks).toHaveLength(7);
  expect(s.tracks.every((t) => t.kind === 'guitar' && t.stringCount === 6)).toBe(true);
  expect(s.tracks[0].tuning).toEqual([63, 58, 54, 49, 44, 39]);
});
```

- [ ] **Step 3: Run them to see them fail**

Run: `npm --prefix engine test`
Expected: FAIL (modules not found)

- [ ] **Step 4: Implement `protocol.ts`, `track_kind.ts`, `summary.ts`, `main.ts`, `index.html` and `build.mjs`**

- [ ] **Step 5: Verify**

Run: `DUOSCORE_PRIVATE_SAMPLE="/Users/eordonez/Desktop/2. Guitar Pro Files/07 Collateral Damage.gp" npm --prefix engine test && npm --prefix engine run build && ls assets/engine`
Expected: all tests pass, the private-sample one included; `assets/engine/` holds `index.html`, `engine.js` and the copied alphaTab files.

- [ ] **Step 6: Commit**

```bash
git add engine .gitignore && git commit -m "feat: add the alphaTab engine package with song summaries"
```

---

### Task 10: Dart engine bridge and host

**Files:**
- Create: `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/engine/engine_transport.dart`, `lib/engine/asset_server.dart`, `lib/engine/engine_host.dart`
- Modify: `pubspec.yaml` (`flutter: assets: - assets/engine/`), `lib/core/dependency_injection.dart` (start the server, create `EngineHost` and `EngineBridge`)
- Test: `test/unit/engine/engine_bridge_test.dart`, `test/unit/engine/protocol_test.dart`, `test/unit/engine/asset_server_test.dart`

**Interfaces:**
- Consumes: the protocol of Task 9; the Task 2 report (server or `file://`).
- Produces:
  - `protocol.dart`: `enum TrackKind { guitar, drums, other }`; `class TrackSummary { final int index; final String name; final TrackKind kind; final int? stringCount; final List<int>? tuning; final int midiProgram; }`; `class SongSummary { final String title; final List<TrackSummary> tracks; List<TrackSummary> get guitarTracks; }`; `fromJson` factories for both.
  - `abstract interface class EngineTransport { Future<void> send(String json); Stream<String> get incoming; }`
  - `class EngineBridge` with `EngineBridge(EngineTransport transport, {Duration timeout = const Duration(seconds: 15)})`, `Future<bool> get ready`, `Future<SongSummary> summarize(String documentsRelativePath)`, `Future<SongSummary> open(String documentsRelativePath)`, `Future<void> renderTrack(int index)`, `Stream<EngineEvent> get events`, `void dispose()`. A failed reply throws `EngineException(String message)`; no reply within `timeout` throws `EngineTimeout`.
  - `class AssetServer` with `static Future<AssetServer> start({required Directory engineAssets, required Directory documents})`, `Uri get engineUri` (`/engine/index.html`), `Uri songUri(String documentsRelativePath)` (`/songs/<path>`), `Future<void> close()`. It binds `127.0.0.1` only, serves `/engine/**` from the unpacked engine assets and `/songs/**` from Documents read-only, and rejects paths that escape either root.
  - `class EngineHost` owns the single `WebViewController` and a `WebViewTransport implements EngineTransport` (`runJavaScript('window.duoscore.handle(<json>)')` out, `JavaScriptChannel('DuoScore')` in), created once in `setupDependencies()` and loading `engineUri`. `EngineView()` is the `WebViewWidget` for that controller. It sits in the score column (Task 13); the shell's `IndexedStack` (Task 7) mounts the Editor page from launch and keeps it mounted, so the engine runs while other tabs show.
  - Flutter's asset bundle is copied once at launch into `Application Support/engine/<build number>/` so the server can serve it from disk.

- [ ] **Step 1: Write the failing tests**

```dart
test('answers a request with the reply carrying the same id', () async {
  final t = FakeTransport(); final b = EngineBridge(t);
  final f = b.summarize('a.gp');
  final sent = jsonDecode(t.sent.single) as Map;
  expect(sent['type'], 'summarize');
  t.reply({'id': sent['id'], 'ok': true, 'payload': {'title': 'A', 'tracks': []}});
  expect((await f).title, 'A');
});
test('throws EngineException on an error reply', …);
test('times out a request the engine never answers', () async {
  final b = EngineBridge(FakeTransport(), timeout: const Duration(milliseconds: 50));
  await expectLater(b.summarize('a.gp'), throwsA(isA<EngineTimeout>()));
});
test('ready completes on the ready event', …);
test('parses a song summary', …); // kinds, nullable tuning, guitarTracks filter
test('serves Documents read-only and refuses paths outside it', () async {
  // GET /songs/a.gp → 200 with bytes; GET /songs/../secret → 404; PUT → 405
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/engine`
Expected: FAIL

- [ ] **Step 3: Implement the protocol, bridge, server and host**

- [ ] **Step 4: Verify on the simulator**

Run: `npm --prefix engine run build && flutter test && flutter analyze && flutter run -d "iPhone Duo"`, with a temporary `debugPrint` of `await bridge.ready` and of a `summarize` call on a file copied into the app's Documents (`cp "$DUOSCORE_PRIVATE_SAMPLE" "$(xcrun simctl get_app_container booted dev.edbrsk.duoscore data)/Documents/"`). Remove the prints.
Expected: tests pass; the log shows `ready` and a summary with 7 guitar tracks.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: bridge Flutter to the alphaTab engine in a web view"
```

---

### Task 11: Song library

**Files:**
- Create: `lib/features/library/song_list_entry.dart`, `lib/features/library/library_cubit.dart`, `lib/features/library/library_page.dart`
- Modify: `ios/Runner/Info.plist` (`UIFileSharingEnabled` = true, `LSSupportsOpeningDocumentsInPlace` = true), `lib/l10n/app_en.arb` (`libraryEmpty: "Add Guitar Pro or MusicXML files in the Files app, under On My iPhone › DuoScore"`, `unreadableFile: "Can't open this file"`, `newSong: "New song"`, `stringsCount: "{count} strings"`)
- Test: `test/unit/features/library/library_cubit_test.dart`, `test/widget/library/library_page_test.dart`

**Interfaces:**
- Consumes: `EngineBridge.summarize`, `SongSummary` (Task 10).
- Produces: `class SongListEntry { final String path; final String title; final String? tuningLabel; final int? stringCount; final bool readable; }` (`path` relative to Documents; `tuningLabel` is the first guitar track's open strings low to high as note names with flats, e.g. `E♭ A♭ D♭ G♭ B♭ E♭` from `[63, 58, 54, 49, 44, 39]`); `class LibraryCubit extends Cubit<LibraryState>` with `LibraryCubit({required Directory documents, required EngineBridge engine})`, `Future<void> refresh()`; `LibraryState { final bool loading; final List<SongListEntry> songs; }` sorted by title; `LibraryPage({required void Function(String path) onOpen})`. The "New song" button is shown disabled until Plan 3.
- Entries are cached in memory by path and modification time, so `refresh()` asks the engine only about changed files. A summarize that throws makes the entry unreadable, titled with the file name.

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<LibraryCubit, LibraryState>('lists supported files sorted by title',
  // temp Documents with b.gp, a.gp5, notes.txt; fake engine returns titles 'B' and 'A'
  expect: () => [isLoading, hasTitles(['A', 'B'])]);   // notes.txt ignored
test('lists a broken file as unreadable', …);           // engine throws EngineException for a.gp5
test('asks the engine only about files that changed', …); // fake engine call count after touching one file
test('labels the tuning low to high with flats', …);    // [63,58,54,49,44,39] → 'E♭ A♭ D♭ G♭ B♭ E♭'
testWidgets('shows title, tuning and string count', …);
testWidgets('shows the empty-library hint', …);
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/library test/widget/library`
Expected: FAIL

- [ ] **Step 3: Implement**

`main()` resolves Documents with `getApplicationDocumentsDirectory()` and registers `LibraryCubit` in `setupDependencies()`. The library refreshes when the engine is ready and when the app returns to the foreground (`AppLifecycleListener.onResume`), so files added in the Files app appear.

- [ ] **Step 4: Verify**

Run: `flutter test && flutter analyze`. Then on the simulator, with the private sample copied into the app's Documents (Task 10 Step 4), relaunch.
Expected: tests pass; the library shows "Collateral Damage", `E♭ A♭ D♭ G♭ B♭ E♭`, "6 strings", and the Files app lists the DuoScore folder.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: list songs from the DuoScore Files folder"
```

---

### Task 12: Open files from other apps

**Files:**
- Modify: `ios/Runner/Info.plist` (`CFBundleDocumentTypes` for the supported extensions; `UTImportedTypeDeclarations` for the Guitar Pro and MusicXML types, each conforming to `public.data`; take the identifiers from the `Info.plist` inside the owner's Guitar Pro 8 app bundle on the Mac, `/Applications/Guitar Pro 8.app/Contents/Info.plist`)
- Modify: `ios/Runner/AppDelegate.swift` (an `IncomingFilesStreamHandler`; the scene delegate's `scene(_:openURLContexts:)` and the launch `connectionOptions.urlContexts` copy each URL, inside `startAccessingSecurityScopedResource`, to `Caches/incoming/<uuid>/<original name>`, then send that path)
- Create: `lib/features/import/incoming_files_provider.dart`, `lib/features/import/unique_destination.dart`
- Test: `test/unit/features/import/unique_destination_test.dart`, `test/unit/features/import/incoming_files_provider_test.dart`

**Interfaces:**
- Consumes: `LibraryCubit.refresh()` (Task 11), `NavigationCubit.select` (Task 7), `ScoreCubit.open` (Task 13; wire it in Task 13).
- Produces: `File uniqueDestination(Directory dir, String fileName)`; `class IncomingFilesProvider` with `IncomingFilesProvider({Stream<dynamic>? events, required Directory documents, required Future<void> Function(String path) onImported})`. It moves each incoming file into Documents at `uniqueDestination`, deletes the staging folder, then calls `onImported` with the path relative to Documents. Channel `dev.edbrsk.duoscore/incoming_files`.

- [ ] **Step 1: Write the failing tests**

```dart
test('uniqueDestination adds a counter before the extension', () {
  // dir contains '07 Collateral Damage.gp' and '07 Collateral Damage (2).gp'
  expect(p.basename(uniqueDestination(dir, '07 Collateral Damage.gp').path),
      '07 Collateral Damage (3).gp');
  expect(p.basename(uniqueDestination(dir, 'new.gp').path), 'new.gp');
});
test('moves an incoming file into Documents and reports it', () async {
  // staged file in tmp/incoming/x/song.gp → documents/song.gp exists, staging dir gone, onImported('song.gp') called once
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/import`
Expected: FAIL

- [ ] **Step 3: Implement the Dart side, then the Swift handler and the plist entries**

- [ ] **Step 4: Verify on the simulator**

Run: `flutter test && flutter analyze && flutter run -d "iPhone Duo"`. Drag a song from the Mac onto the simulator so it lands in Files under "On My iPhone" (outside DuoScore), long-press it, choose Share › DuoScore.
Expected: DuoScore opens and the file appears in the library. Sharing the same file again adds `(2)`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: open Guitar Pro and MusicXML files shared from other apps"
```

---

### Task 13: Read-only score view

**Files:**
- Create: `lib/features/score/score_cubit.dart`, `lib/features/score/score_page.dart`, `lib/features/score/track_panel.dart`
- Modify: `lib/main.dart` (Editor tab → `ScorePage`; library `onOpen` → `ScoreCubit.open` + switch to Editor; `IncomingFilesProvider.onImported` → refresh, open, switch), `lib/l10n/app_en.arb` (`noGuitarTrack: "This song has no guitar track"`, `noSongOpen: "Open a song from the library"`, `tracksHeading: "Tracks"`)
- Test: `test/unit/features/score/score_cubit_test.dart`, `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes: `EngineBridge.open`, `EngineBridge.renderTrack`, `SongSummary` (Task 10); `EngineView` (Task 10); `WorkspaceLayout` (Task 8).
- Produces: `class ScoreCubit extends Cubit<ScoreState>` with `ScoreCubit({required EngineBridge engine})`, `Future<void> open(String path)`, `Future<void> selectTrack(int trackIndex)`; `ScoreState { final SongSummary? song; final String? path; final int? selectedTrackIndex; final bool loading; final String? error; }`. Opening asks the engine to open the file, selects the first guitar track and asks the engine to render it. A song with none leaves `selectedTrackIndex` null and renders nothing.
- `ScorePage` fills `WorkspaceLayout`. `score` is the song title above `EngineView()` (which scrolls itself); `trackPanel` lists `song.guitarTracks` by name with the selected one highlighted; `palette` is an empty panel until Plan 3. The engine draws on `AppColors.paper`.

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<ScoreCubit, ScoreState>('opening selects and renders the first guitar track', …);
  // fake engine: open → tracks [drums, guitar, guitar]; expect selectedTrackIndex 1 and renderTrack(1) called
blocTest<ScoreCubit, ScoreState>('a song without guitar tracks selects none', …);
blocTest<ScoreCubit, ScoreState>('reports an engine error', …); // open throws EngineException → state.error set, loading false
testWidgets('lists only guitar tracks and switches between them', (tester) async {
  expect(find.text('Guitar 1'), findsOneWidget);
  expect(find.text('Drums'), findsNothing);
  await tester.tap(find.text('Guitar 2')); await tester.pump();
  expect(engine.rendered.last, 2);
});
testWidgets('says when a song has no guitar track', …);  // 'This song has no guitar track'
testWidgets('asks to open a song when none is open', …); // 'Open a song from the library'
```

The widget tests replace `EngineView` with a placeholder through the widget's injection point, since a real web view cannot run under `flutter test`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/unit/features/score test/widget/score`
Expected: FAIL

- [ ] **Step 3: Implement `ScoreCubit`, `ScorePage` and `TrackPanel`**

- [ ] **Step 4: Verify the whole plan on the simulator**

Run: `npm --prefix engine run build && flutter test && flutter analyze && flutter run -d "iPhone Duo"`, then:
1. The library shows Collateral Damage. Tap it: the Editor tab shows "Guitar 1" as notation over E♭-standard tab, wrapped into lines and centred, with Guitar 1–7 in the right panel under the vertical bar.
2. Tap "Guitar 3": the score switches.
3. Close the device in Device Hub: the folded screen appears. Reopen it: the same song and track are still shown.
4. Rotate so the bar moves to the left: the layout mirrors, and the score stays centred.

Save screenshots of 1, 3 and 4 to `test_assets_private/plan1/`.
Expected: all four behave as described.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: show guitar tracks as notation over tab"
```
