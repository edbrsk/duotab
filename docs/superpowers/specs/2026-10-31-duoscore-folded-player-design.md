# DuoScore Folded: a Player on the Outer Screen

**Status:** design, awaiting the owner's review.
**Extends:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`. It replaces goal 7 ("Run only unfolded") and the **Closed** rule under iPhone Duo behaviour.

## Why

Closed, DuoScore shows only "Open your iPhone Duo to continue" and pauses. The owner wants to use the closed phone as a player in every way they practise: holding it and following the sheet, standing it on a music stand while playing, and listening on AirPods. Editing stays a job for the open phone.

## Goals

1. Closed, the outer screen shows the app, not a placeholder: the song's sheet, the transport and the track drawer with its mixer.
2. The vertical bar carries the app's navigation when the phone is closed, as it does when it's open.
3. Songs play on the outer screen as they do on the open phone.
4. The screen stays awake while a song plays, open or closed, so it can be read on a music stand.
5. The track panel can be opened on the outer screen, covering it.

## Non-goals

- Editing on the outer screen.
- A layout for the outer screen in landscape, beyond what fits the same rules.
- Playback with the screen locked or the app in the background. iOS stops the web view's audio then, and keeping it going is a separate audio design.
- Playback carrying on through folding or unfolding, for now.

## Anti-goals

- Folding or unfolding moves the playback position.
- Folding loses anything: the open song, the selection, undo history, the loop or unsaved edits.
- An editing control can be reached on the outer screen.
- The vertical bar reads as a dark strip cutting the layout (the main spec's anti-goal, now on both displays).

## The owner's decisions

Mockups: `.superpowers/brainstorm/31075-1793438489/content/folded-layout-v2.html`, option **A** chosen, and the track panel screen beside it. The mockup's tone list is illustrative: the tones are the app's three (Clean, Overdrive, High gain).

### The outer screen (option A)

- **Sheet, transport, drawer:** top to bottom, the drawn track's sheet, the transport (play/pause, speed, loop, bar), and the track drawer with its Mixer toggle. This is the play-only layout the app already uses in Split View.
- **Vertical bar:** two glass capsules, as in dreambudget. At the bottom is the tab capsule: Library, the song tab (Editor when open) and Settings. Above it is an **actions capsule** holding ☰, which opens the track panel.
- **No editing:** no palette, no fret selector, no Add track, no ⋮ track menu, as in Split View today.

### The track panel, closed

- It covers the screen beside the bar, which keeps its capsules. The actions capsule shows ✕ in place of ☰, and ✕ goes back to the sheet.
- It holds the track name (shown, not renamable), tuning and string count, standard notation and tab on or off, and tone. Everything that edits is left out: the fret selector, Retune and the retune report's buttons.

### Behaviour

- **Folding pauses playback**, as it does today. The position, speed and loop stay, and play continues from there.
- **The screen stays on** while a song plays, open or closed. Once playback pauses or stops, the screen dims as usual.
- **Library and Settings** work fully on the outer screen: opening and importing songs, and every setting.
- **The mixer drawer** stays open or closed as it was across folding and unfolding.
- **Changes made closed** (faders, pans, mute, solo, tone, staves, loop, speed) are saved per song exactly as they are when open.

## Calls I made (the owner can overrule)

- **Unfolding pauses too**, for the same reason: both redraw the sheet at a new width.
- **The banner** over the sheet reads "Open your iPhone Duo to edit" when the phone is closed, and stays "Make DuoScore wider to edit" in Split View.
- **Split View gets ☰ too:** the play-only layout is the same layout open or closed, so the full-screen track panel and its ☰ button exist wherever the side panels are collapsed. Where no vertical bar is present, ☰ sits at the top right of the score column.
- **Unfolding with the track panel open** closes it. The phone then shows the usual three columns, where the panel is a side panel again.
- **Tapping the sheet** in the play-only layout seeks to the tapped beat and doesn't move the edit cursor. A long press sets the loop, as it does open.
- **The song tab** keeps its name and icon when closed. It is the same page, and the banner says why it doesn't edit.
- **The actions capsule** shows only on the song page in the play-only layout. Library and Settings have no actions in the bar.
- **The song title** can't be renamed in the play-only layout.
- **The selection and the editor's state** stay as they were. The engine keeps them; they simply have no controls while closed.
- **The sheet keeps its drawing scale** and wraps to the narrower width, as it does in Split View. alphaTab lays it out again for the new width, and the cursor follows the playing bar.
- **Hinge status unknown or missing** counts as open, as it does today (`HingeStatusProvider.isOpen`).

## Constraints (the app as built)

- **Outer screen:** 466 × 678 pt with the vertical bar on the trailing edge, 84 pt wide (measured in dreambudget, `test/widget/navigation/vertical_bar_app_bar_test.dart`). That leaves 382 pt for the app, under `kThreeColumnMinWidth` (720), so `WorkspaceLayout.isCollapsed` already picks the play-only layout. Layout follows the window size and safe areas, never the hinge state, by the main spec's layout rules. The hinge only decides the banner text and the panel closing on unfold.
- **Today's fold handling:**
  - `FoldGate` (`lib/presentation/shell/fold_gate.dart`) puts the app shell offstage behind `FoldedScreen` when closed.
  - `PlaybackCubit._onHingeChanged` pauses on close. It stays, and pauses on unfold too.
  - `FoldGate`, `FoldedScreen` and the `foldedMessage` string go, unless something else still uses them.
- **Keeping the screen on:** iOS's `UIApplication.isIdleTimerDisabled`, reached through a bridge or a package whose licence allows bundling (main spec, Licences).
- **The bar:** `AppShell` (`lib/presentation/shell/app_shell.dart`) draws only the tab capsule in the bar. Dreambudget's `VerticalBarAppBar` and `VerticalBarCapsulePortal` (`/Users/eordonez/Code/sideprojects/dreambudget_app/lib/presentation/widgets/`) put a page's actions in a second capsule above the tabs. The main spec names them as the pattern to port, and only the tab rail has been ported so far.
- **One web view:** the score's `WKWebView` is the same one open and closed. Folding resizes it, and alphaTab redraws the score at the new width. On a long song (*Collateral Damage*: 153 bars, 7 tracks) that redraw takes noticeable time.
- **The main spec** changes with this design:
  - goal 7 and the **Closed** rule are replaced;
  - the **Split View** rule gains the ☰ track panel;
  - "What the app does when the hinge status is unknown" is no longer an open question under Left to the builder.

## Left to the builder

- How the full-screen track panel is presented (a route, an overlay, a page in the stack), within the mockup.
- Whether the banner shows over the sheet on the outer screen at all, or is dropped there to save height.
- Any placeholder shown while the sheet redraws after folding.
- Sizes of the drawer and transport on the outer screen, within the mockup.

## Acceptance

- With *Parade of Rage* playing on the open phone, folding it pauses the song. The outer screen shows the sheet at the paused bar, the transport and the drawer, and play continues from that bar. Unfolding pauses it again and brings back the three columns at the same bar.
- While a song plays on the outer screen, the screen doesn't dim or lock. After pausing, it dims as usual.
- On the outer screen, the bar shows ☰ above the Library, song and Settings tabs, all of which work.
- ☰ opens the track panel over the screen, without the fret selector. Changing the tone there changes the sound, ✕ returns to the sheet, and the tone is still set after reopening the app.
- On the outer screen, the mixer's faders, pans, mute and solo work as they do when open, and the meters move.
- No control on the outer screen edits the song: no palette, fret selector, Add track, track menu or renaming.
- An edit made before folding, and the undo history, are intact after folding and unfolding.
- In Split View, ☰ opens the same track panel.
