# DuoScore Plan 10: Folded Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The closed iPhone Duo's outer screen runs DuoScore as a player: the sheet, transport and mixer drawer, the tabs and a track-panel button in the vertical bar, a full-screen track panel without editing, and the screen kept awake while a song plays.

**Architecture:** The play-only layout already exists: `WorkspaceLayout.isCollapsed` (width < 720) picks it in Split View, and the 382 pt left beside the outer screen's bar is narrower than that. This plan:
- removes the fold gate;
- lets a page put actions in the vertical bar above the tabs (`BarActions`);
- makes the score page's play-only layout open a full-screen, non-editing `TrackInfoPanel` and stop a tap from moving the edit cursor;
- pauses playback on every fold and unfold;
- keeps the screen awake through a small native bridge.

There are no engine changes.

**Tech Stack:** Flutter 3.47.8 (Dart), `flutter_bloc`, `provider`, `mocktail`/`bloc_test`, Swift in `ios/Runner/AppDelegate.swift`.

**Spec:** `docs/superpowers/specs/2026-10-31-duoscore-folded-player-design.md` (extends `docs/superpowers/specs/2026-10-29-duoscore-design.md`)

## Global Constraints

- Layout follows the window size and safe areas, never the hinge. The hinge decides only the banner text and pausing.
- The banner over the sheet reads `Open your iPhone Duo to edit` when the hinge is closed, and `Make DuoScore wider to edit` otherwise.
- The track-panel button's tooltip reuses `showTrackPanel` (`Show track panel`) and, while the panel is open, `hideTrackPanel` (`Hide track panel`). The icons are `Icons.menu` and `Icons.close`.
- Hinge status unknown or missing counts as open (`HingeStatusProvider.isOpen`, unchanged).
- Tones stay the app's three; the mockup's list is illustrative.
- Comments: none that restate the code or its names. Only a non-obvious why, kept to one line.
- Checks:
  - `flutter test` and `flutter analyze` must stay green;
  - `dart format` runs only on the files a task touches;
  - `npm --prefix engine test` stays green, since nothing here touches the engine.
- Simulator:
  - build with `flutter build ios --simulator`;
  - install with `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`;
  - launch with `xcrun simctl launch --terminate-running-process booted dev.edbrsk.duoscore`.

## Review Focus

1. **Folding with the mixer open:** the drawer is still in Mixer mode on the outer screen, and after unfolding (Task 5: `the score column keeps its state when the layout collapses`).
2. **Unfolding or widening while the full-screen panel is open:** the panel closes, and the three columns come back with the side panel and its fret selector (Task 4: `widening the window closes the play-only panel`).
3. **The Library or Settings tab while folded:** the bar shows only the tabs, with no ☰ (Task 1: `actions show only on their own tab`).
4. **Folded with no song open:** no ☰ anywhere (Task 4: `no song, no track panel button`).
5. **Moving between partly and fully open:** this isn't a fold, so playback keeps going (Task 5: `moving between partly and fully open doesn't pause`).

---

### Task 1: Page actions in the vertical bar

**Files:**
- Create: `lib/presentation/shell/bar_actions.dart`
- Modify: `lib/presentation/shell/app_shell.dart`
- Test: `test/widget/shell/app_shell_test.dart`

**Interfaces:**
- Produces:
  - `class BarAction { const BarAction({required IconData icon, required String tooltip, required VoidCallback onPressed}); final IconData icon; final String tooltip; final VoidCallback onPressed; }`
  - `class BarActions extends ChangeNotifier { List<BarAction> of(AppTab tab); void set(AppTab tab, List<BarAction> actions); static BarActions? maybeOf(BuildContext context); }`. `set` notifies only when an icon or tooltip changes, and always keeps the newest callbacks. `maybeOf` reads without listening (`Provider.of<BarActions?>(context, listen: false)`) and returns null when no shell is above.
  - `class BarActionsFor extends StatefulWidget { const BarActionsFor({required AppTab tab, required List<BarAction> actions, required Widget child}); }`. It publishes `actions` for `tab` after each build (post-frame, so it never notifies during a build), and sets `[]` on dispose.
  - `AppShell` becomes a `StatefulWidget` that owns one `BarActions` and provides it with `ChangeNotifierProvider.value` around its pages. When the bar is present, it draws the current tab's actions in a `GlassCapsule` of `IconButton`s, with a `Spacing.sm` gap above the `AppNavigationRail`. Only that capsule listens, through `ListenableBuilder`; pages are never rebuilt by it. With no bar it draws no actions.

- [ ] **Step 1: Write the failing tests** in `app_shell_test.dart`, using the file's `pumpShell` with `barEdge: 'trailing'` and right padding 84. `pageFor` returns `BarActionsFor(tab: AppTab.editor, actions: [BarAction(icon: Icons.menu, tooltip: 'Show track panel', onPressed: () => tapped++)], child: const _Counter())` for the editor tab, and `const _Counter()` otherwise.
  - `a page's bar actions sit above the tabs`:
    - with the editor tab selected, `find.byTooltip('Show track panel')` finds one widget;
    - its centre's `dy` is less than `tester.getTopLeft(find.byType(AppNavigationRail)).dy`;
    - its centre's `dx` is within the right 84 pt;
    - tapping it makes `tapped == 1`.
  - `actions show only on their own tab`: after `navigation.select(AppTab.library)` and a pump, `find.byTooltip('Show track panel')` finds nothing.
  - `a page that goes takes its actions with it`: rebuild with an editor page that has no `BarActionsFor`; after a pump the tooltip finds nothing.
  - `no bar, no actions capsule`: with `barEdge: 'unspecified'`, the tooltip finds nothing.
  - `bar actions don't rebuild the pages`: tap the `_Counter` once ("count: 1"), then call `set` with new callbacks but the same icon and tooltip. "count: 1" is still shown, and the state survives.

- [ ] **Step 2: Run them to verify they fail**
  Run: `flutter test test/widget/shell/app_shell_test.dart`
  Expected: compile errors, because `BarActionsFor` and `BarAction` aren't defined.

- [ ] **Step 3: Implement `bar_actions.dart` and the shell changes** as the Interfaces block says.

- [ ] **Step 4: Run them to verify they pass**
  Run: `flutter test test/widget/shell/app_shell_test.dart`
  Expected: all pass, including the file's earlier tests.

- [ ] **Step 5: Commit**
  `git add lib/presentation/shell test/widget/shell && git commit -m "feat(shell): pages can put actions in the vertical bar, above the tabs"`

### Task 2: A track panel without editing

**Files:**
- Modify: `lib/features/score/track_info_panel.dart`
- Test: `test/widget/score/track_info_panel_test.dart`

**Interfaces:**
- Produces: `const TrackInfoPanel({bool editable = true, Key? key})`. With `editable: false`:
  - the track name is a plain `Text` in `titleMedium`, with no rename button;
  - the Retune button and `_RetuneReportCard` are gone;
  - the Fret heading and `FretPad` are gone.

  Tuning, string count, the two notation chips and the three tone radios stay.

- [ ] **Step 1: Write the failing test** `a play-only panel has nothing that edits`. Pump the panel the way the file's other tests do, with `editable: false`, then expect:
  - `find.byType(FretPad)` finds nothing;
  - `find.byTooltip('Rename track')` finds nothing;
  - `find.text('Retune…')` finds nothing;
  - `find.text(<the drawn track's name>)` finds one widget;
  - `find.byType(FilterChip)` finds 2 widgets;
  - `find.byType(RadioListTile<Tone>)` finds 3 widgets.

  Tapping the `High gain` radio verifies `playback.setTone(<index>, Tone.highGain)`.
- [ ] **Step 2: Run it to verify it fails**
  Run: `flutter test test/widget/score/track_info_panel_test.dart`
  Expected: compile error, `No named parameter with the name 'editable'`.
- [ ] **Step 3: Implement the `editable` parameter.**
- [ ] **Step 4: Run it to verify it passes**
  Run: `flutter test test/widget/score/track_info_panel_test.dart`
  Expected: all pass.
- [ ] **Step 5: Commit**
  `git add lib/features/score/track_info_panel.dart test/widget/score/track_info_panel_test.dart && git commit -m "feat(score): a track panel without editing, for the play-only layout"`

### Task 3: A tap that doesn't place the edit cursor

**Files:**
- Modify: `lib/features/editor/editor_cubit.dart`
- Test: `test/unit/features/editor/editor_cubit_test.dart`

**Interfaces:**
- Produces: `bool placesOnTap` on `EditorCubit`, a plain field defaulting to `true`. While it's false, an engine `tapped` event is ignored. The engine has already sought to the beat.

- [ ] **Step 1: Write the failing test** `a tap doesn't place the cursor while playing only`:
  - set `editor.placesOnTap = false`, send the same `tapped` event as `a tap places the cursor`, pump, then `verifyNever(() => engine.edit(const Place(_at)))`;
  - set `editor.placesOnTap = true`, send it again, pump, then `verify(() => engine.edit(const Place(_at))).called(1)`.
- [ ] **Step 2: Run it to verify it fails**
  Run: `flutter test test/unit/features/editor/editor_cubit_test.dart`
  Expected: compile error, because the `placesOnTap` setter isn't defined.
- [ ] **Step 3: Implement the field and the check** in the `tapped` listener.
- [ ] **Step 4: Run it to verify it passes**
  Run: `flutter test test/unit/features/editor/editor_cubit_test.dart`
  Expected: all pass.
- [ ] **Step 5: Commit**
  `git add lib/features/editor/editor_cubit.dart test/unit/features/editor/editor_cubit_test.dart && git commit -m "feat(editor): a tap can leave the edit cursor where it is"`

### Task 4: The score page's play-only layout

**Files:**
- Modify: `lib/features/score/score_page.dart`
- Test: `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes:
  - `BarAction`, `BarActionsFor` and `BarActions` from Task 1;
  - `TrackInfoPanel(editable: false)` from Task 2;
  - `EditorCubit.placesOnTap` from Task 3;
  - `VerticalBarEdgeProvider.edgeOf` and `WorkspaceLayout.isCollapsed`.
- Produces: `ScorePage` becomes a `StatefulWidget` with the same constructor.
  - **Play-only:** when `WorkspaceLayout.isCollapsed(context)` and a song is open, the page has a track-panel button.
    - With a vertical bar (`edgeOf` isn't `unspecified`), it's published with `BarActionsFor(tab: AppTab.editor, …)`.
    - With no bar, it's an `IconButton` at the end of the title row.
    - Either way: `Icons.menu` with tooltip `showTrackPanel`, or `Icons.close` with `hideTrackPanel` while the panel is open. Pressing it toggles the panel.
  - **The open panel** is `TrackInfoPanel(editable: false)` on `AppColors.panel` in a `Stack` over the whole page, keyed `Key('playOnlyPanel')`, padded by the view's left, right and top safe area plus `Spacing.md`.
  - **Wider layout:** the open-panel state resets to closed whenever the layout isn't collapsed, as on unfolding or widening a Split View.
  - **Title:** while collapsed it's a plain `Text` in the title's style; the Change title button is gone.
  - **Taps:** `didChangeDependencies` sets `context.read<EditorCubit>().placesOnTap = !collapsed`.

- [ ] **Step 1: Write the failing tests** in `score_page_test.dart`. Extend `pumpPage` with optional `VerticalBarEdgeProvider? edge` and `BarActions? barActions`, provided with `ChangeNotifierProvider.value` when given. The mock editor records the `placesOnTap` setter. With `fixture.gp` open:
  - `play-only: the track panel button opens the panel over the page`:
    - at width 466 with no bar, tap the `Show track panel` tooltip, then pump;
    - `find.byKey(const Key('playOnlyPanel'))` finds one widget, inside which `FretPad` finds nothing;
    - tap `Hide track panel`, then pump; the key finds nothing.
  - `with the vertical bar, the button goes to the bar`:
    - at width 466, with right padding 84, `edge` set to trailing and `barActions` provided, pump twice so the post-frame publishes;
    - `barActions.of(AppTab.editor)` has one action, `Show track panel` with `Icons.menu`, and there is no `IconButton` with that tooltip in the page;
    - call its `onPressed` and pump: the panel key finds one widget, and the action is now `Hide track panel` with `Icons.close`.
  - `widening the window closes the play-only panel`:
    - open the panel at width 466, then pump the page again at width 890;
    - the panel key finds nothing, and `FretPad` finds one widget in the side panel;
    - back at width 466, the panel key still finds nothing.
  - `no song, no track panel button`: at width 466 with no song open, `Show track panel` finds nothing.
  - `play-only: the title can't be changed`: at width 466, `find.byTooltip('Change title')` finds nothing and the song's title text finds one widget.
  - `play-only: a tap doesn't move the edit cursor`: at width 466, `verify(() => editor.placesOnTap = false)` is called; pump at width 890 and `verify(() => editor.placesOnTap = true)` is called.

- [ ] **Step 2: Run them to verify they fail**
  Run: `flutter test test/widget/score/score_page_test.dart`
  Expected: the new tests fail (no button, title still a button, setter never called). The earlier tests pass.
- [ ] **Step 3: Implement the play-only behaviour** as the Interfaces block says.
- [ ] **Step 4: Run them to verify they pass**
  Run: `flutter test test/widget/score/score_page_test.dart`
  Expected: all pass, including `editing is off when the window is narrow`.
- [ ] **Step 5: Commit**
  `git add lib/features/score/score_page.dart test/widget/score/score_page_test.dart && git commit -m "feat(score): play-only, the track panel opens over the page and taps only seek"`

### Task 5: The folded screen shows the app

**Files:**
- Delete:
  - `lib/presentation/shell/fold_gate.dart`
  - `lib/presentation/shell/folded_screen.dart`
  - `test/widget/shell/fold_gate_test.dart`
- Modify:
  - `lib/main.dart` (no `FoldGate` around `AppShell`)
  - `lib/l10n/app_en.arb` (drop `foldedMessage`; add `"openToEdit": "Open your iPhone Duo to edit"`), then `flutter gen-l10n`
  - `lib/presentation/workspace/workspace_layout.dart` (`_WiderToEditBanner`, and the score column's key)
  - `lib/features/playback/playback_cubit.dart` (`_onHingeChanged`)
  - `docs/superpowers/specs/2026-10-29-duoscore-design.md`
- Test:
  - `test/widget/workspace/workspace_layout_test.dart`
  - `test/unit/features/playback/playback_cubit_test.dart`

**Interfaces:**
- Consumes: `HingeStatusProvider.isOpenOf(context)` and `HingeStatusProvider.isOpen`.
- Produces:
  - **Banner:** it shows `openToEdit` when `isOpenOf(context)` is false, and `widerToEdit` otherwise.
  - **Keeping state:** `WorkspaceLayout` builds its score column under a `GlobalKey` it owns, so the column keeps its state, the drawer's Mixer toggle with it, when the layout collapses or widens. The column moves between a `Row` and a lone `Padding`, which would otherwise rebuild it.
  - **Pausing:** `PlaybackCubit` remembers the last `hinge.isOpen` (starting from its value at construction) and pauses whenever it changes, in either direction.

- [ ] **Step 1: Write the failing tests:**
  - `workspace_layout_test.dart`, `folded, the banner says to open the phone`: a collapsed layout (width 466) under `ChangeNotifierProvider.value(value: HingeStatusProvider(hingeEvents: Stream.value('closed')))`, pumped twice, shows `Open your iPhone Duo to edit`, and `Make DuoScore wider to edit` finds nothing.
  - `workspace_layout_test.dart`, `the score column keeps its state when the layout collapses`: a `drawer` that is a stateful counter, tapped once at width 890, still shows "count: 1" after re-pumping at width 466 and again at 890. WorkspaceLayout has to be a `StatefulWidget` to own the key.
  - `playback_cubit_test.dart`, `unfolding pauses too`:
    - `playing(on: true)`, send `closed`, pump; `playing(on: true)` again, send `fullyOpen`, pump;
    - `verify(() => engine.pause()).called(2)`.
  - `playback_cubit_test.dart`, `moving between partly and fully open doesn't pause`:
    - send `fullyOpen`, then `playing(on: true)`, send `partiallyOpen`, pump, then `fullyOpen`, pump;
    - `verifyNever(() => engine.pause())`.
- [ ] **Step 2: Run them to verify they fail**
  Run: `flutter test test/widget/workspace/workspace_layout_test.dart test/unit/features/playback/playback_cubit_test.dart`
  Expected:
  - the banner test fails because the text isn't found;
  - the state test fails, showing "count: 0" after collapsing;
  - `unfolding pauses too` fails, called 1 time instead of 2;
  - `moving between partly and fully open` passes already, since today only a close pauses. It guards the new change-tracking.
- [ ] **Step 3: Implement:**
  - the banner text, the `openToEdit` string, the score column's key and the hinge-change pause;
  - remove the fold gate, `FoldedScreen`, their test and `foldedMessage`, then run `flutter gen-l10n`;
  - in the main spec, replace goal 7 with "**Run open or closed**: closed, the outer screen is a player (see `2026-10-31-duoscore-folded-player-design.md`)";
  - replace the **Closed** rule with "the outer screen runs the play-only layout; folding and unfolding pause playback";
  - add "a ☰ button opens the track panel over the page" to the **Split View** rule;
  - delete the "hinge status is unknown" line under Left to the builder.
- [ ] **Step 4: Run them to verify they pass**
  Run: `flutter test && flutter analyze`
  Expected: all pass, `No issues found!`, and `grep -rn "FoldGate\|FoldedScreen\|foldedMessage" lib test` prints nothing.
- [ ] **Step 5: Commit**
  `git add -A lib test docs/superpowers/specs/2026-10-29-duoscore-design.md && git commit -m "feat: closed, the outer screen runs the player; folding either way pauses"`

### Task 6: The screen stays awake while a song plays

**Files:**
- Create: `lib/features/playback/screen_awake.dart`
- Modify:
  - `lib/core/dependency_injection.dart`
  - `ios/Runner/AppDelegate.swift`
- Test: `test/unit/features/playback/screen_awake_test.dart`

**Interfaces:**
- Consumes: `PlaybackCubit.stream` and `PlaybackState.playing`.
- Produces:
  - `StreamSubscription<bool> keepAwakeWhilePlaying(Stream<PlaybackState> states, Future<void> Function({required bool awake}) setAwake)`. It calls `setAwake` once per change of `playing` (`map` + `distinct`), and catches and `debugPrint`s a failed call.
  - `class ScreenAwake { const ScreenAwake(); Future<void> set({required bool awake}); }`. It invokes `setAwake` with the bool on `MethodChannel('dev.edbrsk.duoscore/screen_awake')`, only on iOS (`kIsWeb || defaultTargetPlatform != TargetPlatform.iOS` makes it a no-op, as `output_latency.dart` does).
  - `setupDependencies` calls `keepAwakeWhilePlaying(playback.stream, const ScreenAwake().set)` once the cubit exists.
  - In Swift, a `ScreenAwake` registrar in `didInitializeImplicitFlutterEngine` handles `setAwake` by setting `UIApplication.shared.isIdleTimerDisabled` to the argument (`false` when it isn't a `Bool`). Its doc says the screen won't dim or lock while it's on.

- [ ] **Step 1: Write the failing test** `the screen stays awake only while playing`:
  - feed a `StreamController<PlaybackState>` the states playing false, then true, then true with `bar: 3`, then false;
  - the calls recorded from `setAwake` are `[true, false]`.

  Then `a failed call doesn't stop the next one`: a `setAwake` that throws on its first call still records the second.
- [ ] **Step 2: Run it to verify it fails**
  Run: `flutter test test/unit/features/playback/screen_awake_test.dart`
  Expected: compile error, because `keepAwakeWhilePlaying` isn't defined.
- [ ] **Step 3: Implement** `screen_awake.dart`, the wiring and the Swift handler.
- [ ] **Step 4: Run it to verify it passes, then build**
  Run: `flutter test test/unit/features/playback/screen_awake_test.dart && flutter analyze && flutter build ios --simulator`
  Expected: all pass, `No issues found!`, `✓ Built build/ios/iphonesimulator/Runner.app`.
- [ ] **Step 5: Commit**
  `git add lib/features/playback/screen_awake.dart lib/core/dependency_injection.dart ios/Runner/AppDelegate.swift test/unit/features/playback/screen_awake_test.dart && git commit -m "feat(playback): the screen stays awake while a song plays"`
