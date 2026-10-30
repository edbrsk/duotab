# DuoScore Plan 6a: Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export the open song as `.gp` or as a PDF of the drawn track, through the iOS share sheet.

**Architecture:**
- **`.gp`** is the engine's existing `exportGp`, written to a temporary file named after the song.
- **PDF:** the engine renders the drawn track a second time with its own `ScoreRenderer`, using the SVG engine and page layout. It stacks the staff systems onto A4 pages and returns each page as a self-contained HTML document. Native code loads each page into an off-screen `WKWebView`, captures it with `pdf(configuration:)` and joins the pages with PDFKit.
- **Sharing** is a native `UIActivityViewController`, anchored to the Export button.

**Tech Stack:** as Plan 5c. alphaTab 1.6.1:
- `rendering.ScoreRenderer` with `core.engine = 'svg'`, `core.enableLazyLoading = false`, `display.layoutMode = LayoutMode.Page`;
- `partialRenderFinished` gives one SVG string per header block and per staff system, with its `y` and `height`; the last is a "rendered by alphaTab" line.

  SVG music glyphs are `<text class="at">`, which take their font from page CSS. The CSS is alphaTab's injected rule: `font-family` alphaTab, `font-size` 34px (`Environment.MusicFontSize`, not exported), `line-height: 1`. alphaTab escapes SVG text.

iOS: WebKit (`WKWebView.pdf(configuration:)`, `callAsyncJavaScript`), PDFKit and UIKit (`UIActivityViewController`). No new packages.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`:
- Goals 6: "**Save** as `.gp`; **export** PDF."
- Files › Exports: "shared through the iOS share sheet: `.gp`, and PDF with title, tempo, tuning and notation over tab as alphaTab lays it out in pages."

**Branch:** `plan-6a-export`, from `main`.

## Global Constraints

Plans 1–5c's Global Constraints all apply. In addition:

- **Export button:** an Export button (`Icons.ios_share`) beside the song title opens a menu with **Guitar Pro file (.gp)** and **PDF**. PDF is disabled when the song has no guitar track. The button shows progress and is disabled while an export runs. A failure shows "Couldn't export: {error}".
- **Files:**
  - The file is named `<title>.gp` or `<title>.pdf`.
  - The title is trimmed and has `/`, `\` and `:` replaced by `-`. An empty title gives `Untitled`.
  - Files are written to `<temporary directory>/exports/`, which each export empties first.
- **`.gp`** is the open song as the engine holds it, edits and practice tones and volumes included, as autosave writes it.
- **PDF:**
  - **Content:** the drawn track only, with the staves the track panel shows.
  - **Page:** A4 portrait, 595 × 842 pt, with 36 pt margins, so the content is 523 pt wide and 770 pt tall.
  - **Layout:** alphaTab page layout at width 523, `display.scale` 0.75, with the on-screen stave profile.
  - **Header:** page 1 starts with alphaTab's header (title, subtitle, artist, tuning). The tempo is on the first system.
  - **Page breaks:** a system never splits across pages, and the gaps between systems are kept. A system taller than 770 pt gets a page of its own, clipped at the bottom.
  - **Page numbers:** each page shows "n / N" centred, 20 pt from the bottom edge.
- **Share sheet:** the native `share` always sets `popoverPresentationController.sourceView` and `sourceRect`, from the Export button's rect in global coordinates. In regular width, as on the unfolded Duo, the sheet is a popover and needs that anchor.
- **The `exportPdf` bridge timeout is 60 s;** other requests keep 15 s.
- **Channel:** `dev.edbrsk.duoscore/export`, with methods `pdf` and `share`.

## Review Focus

1. **The share sheet on the unfolded Duo** is a popover. It opens from the Export button and must not crash for want of an anchor. Test: Task 4 `choosing a format exports with the button's rect`. The native side sets the anchor on every call, which Task 2 Step 3 states.
2. **A long song** (Collateral Damage: 153 bars and 19 time signatures) exports within the timeout, with no system split or lost. Tests: Task 1 `a part taller than a page gets a page of its own`, `the private sample prints every system`; Task 3 `exportPdf waits up to a minute`.
3. **A title that isn't a valid file name** ("AC/DC: Back", or empty), or that holds HTML characters ("Rock & <Roll>"), gives a sound file name and a sound page. Tests: Task 3 `file names replace / \ : and fall back to Untitled`; Task 1 `titles are escaped`.
4. **Tapping Export again while an export runs** starts no second export. Test: Task 4 `the button is disabled while an export runs`.
5. **A song with no guitar track** still exports as `.gp`, and offers no PDF. Test: Task 4 `PDF is disabled without a guitar track`.

---

### Task 1: Print pages in the engine

**Files:**
- Create: `engine/src/print_pages.ts`, `engine/test/print_pages.test.ts`
- Modify: `engine/src/protocol.ts`, `engine/src/main.ts`, `engine/test/fixtures.ts`

**Interfaces:**
- Produces, in `print_pages.ts`:
  - `A4 = { width: 595, height: 842, margin: 36 }`;
  - `paginate(parts: { y: number; height: number }[], contentHeight: number): number[][]`, the part indexes on each page, in order;
  - `printPages(score: Score, track: number, staveProfile: alphaTab.StaveProfile, fontUrl: string): string[]`, one HTML document per page.

  Each page document has:
  - `<meta charset="utf-8">` and `<meta name="viewport" content="width=595, initial-scale=1">`;
  - `@font-face` for `alphaTab` from `fontUrl`, in woff2 format;
  - the `.at` rule and `.at-surface-svg text { dominant-baseline: central; white-space: pre }`;
  - a 595 × 842 body with no margin and `overflow: hidden`;
  - each part absolutely placed at `left: 36px` and `top: 36 + (part.y − first part's y on the page)`;
  - the page number.
- Produces, in the protocol:
  - `RequestType` gains `'exportPdf'`;
  - `ExportPdfReply = { pages: string[]; baseUrl: string }`, where `baseUrl` is the engine's origin, which serves the font.
- Produces, in main: `exportPdf` prints `session.track`. It throws `no song open` without a song, and `no guitar track` when the drawn track isn't one (`isGuitar`). It uses `fontUrl = pageUrl('./alphatab/font/Bravura.woff2')` and `baseUrl = location.origin + '/'`.
- Fixture `longRiff`:
  - `\title "Riff" \tempo 140`;
  - one 6-string E standard track;
  - 40 bars of `0.6.4 2.5.4 3.4.4 5.3.4`.

- [ ] **Step 1: Write the failing tests** in `print_pages.test.ts`:
  - **`paginate fills pages and never splits a part`:** parts at y 0/100/400/700 with heights 100/300/300/300, and content 770, give `[[0, 1, 2], [3]]`.
  - **`a part taller than a page gets a page of its own`:** parts at y 0/100/1000 with heights 100/900/100 give `[[0], [1], [2]]`.
  - **`printPages lays the song on numbered A4 pages`:** `longRiff` prints on two or more pages. Page 1 contains `>Riff</text>` and `= 140`. Every page contains the viewport meta, `fontUrl`, and `${i + 1} / ${pages.length}`. The last page contains `rendered by alphaTab`.
  - **`every system is printed once`:** the `<svg` count over all pages equals the number of `partialRenderFinished` parts of the same render.
  - **`titles are escaped`:** a title `Rock & <Roll>` gives `Rock &amp; &lt;Roll&gt;` and no `<Roll>`.
  - **`the private sample prints every system`:** this test reads `DUOSCORE_PRIVATE_SAMPLE` and skips when it is unset. Track 0 prints on 5 or more pages within 20 s, with every system printed once.
- [ ] **Step 2: Run them to verify they fail:** `npm --prefix engine test -- print_pages`. Expected: FAIL, with `print_pages` missing.
- [ ] **Step 3: Implement `paginate` and `printPages`,** then the protocol type and the `exportPdf` case in `main.ts`.
  - **Settings:** `printPages` builds its own `alphaTab.Settings`, so the on-screen renderer is untouched.
  - **Parts:** they are sorted by `y` before paginating.
  - **Breaks:** a page starts at its first part's `y`. A part is added while `part.y + part.height − pageStart ≤ contentHeight`.
- [ ] **Step 4: Run** `npm --prefix engine test && (cd engine && npx tsc --noEmit -p .)`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(engine): print the drawn track on A4 pages`

---

### Task 2: Native PDF and share sheet

**Files:**
- Create: `lib/features/export/export_channel.dart`, `test/unit/features/export/export_channel_test.dart`
- Modify: `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: Task 1's page documents and `baseUrl`.
- Produces (Dart): `class ExportChannel`, over `MethodChannel('dev.edbrsk.duoscore/export')`:
  - `Future<void> makePdf({required List<String> pages, required String baseUrl, required String path})` calls `pdf` with `{pages, baseUrl, path}`;
  - `Future<void> share(List<String> paths, Rect anchor)` calls `share` with `{paths, x, y, width, height}`.

  Platform errors propagate as `PlatformException`.
- Produces (Swift): `SongExport.shared.register(with:)`, registered as plugin `SongExport` in `didInitializeImplicitFlutterEngine`.

- [ ] **Step 1: Write the failing tests** in `export_channel_test.dart`, with a mock method handler on the channel:
  - `makePdf sends pages, base URL and path`;
  - `share sends the paths and the anchor rect`;
  - `a platform error reaches the caller`.
- [ ] **Step 2: Run them to verify they fail:** `flutter test test/unit/features/export/export_channel_test.dart`. Expected: FAIL, with `export_channel.dart` missing.
- [ ] **Step 3: Implement `ExportChannel`, and `SongExport` in `AppDelegate.swift`.** `SongExport` is `@MainActor` and follows `SongPicker`'s registration.
  - **`pdf`:**
    - Create one `WKWebView` of 595 × 842. Add it to the view controller's view at x −10 000 with user interaction off, and remove it at the end.
    - For each page in order:
      1. `loadHTMLString(page, baseURL: URL(string: baseUrl))`, then wait for `didFinish` through a navigation delegate continuation;
      2. `try await callAsyncJavaScript("await document.fonts.load(\"34px alphaTab\"); await document.fonts.ready;", contentWorld: .page)`;
      3. `try await webView.pdf(configuration: WKPDFConfiguration())`;
      4. append that document's page 0 to one `PDFDocument`.
    - Write the document to `path`.
    - Reply `nil`, or `FlutterError(code: "pdf_failed")` with the error's description.
  - **`share`:**
    - Present a `UIActivityViewController` with the file URLs.
    - Always set `popoverPresentationController?.sourceView` to the view controller's view, and `sourceRect` to the given rect.
    - Reply on `completionWithItemsHandler` with whether it completed.
    - A second `share` while one is open replies `FlutterError(code: "unavailable")`.
- [ ] **Step 4: Run** `flutter test test/unit/features/export/export_channel_test.dart && flutter build ios --simulator`. Expected: tests pass, and the build exits 0.
- [ ] **Step 5: Check the page document in desktop WebKit.** This is throwaway work, kept out of the repo:
  1. A temporary engine test writes `printPages(longRiff, …)` to `/tmp/duoscore-print/page-N.html`. Its `fontUrl` is the file URL of `assets/engine/alphatab/font/Bravura.woff2`.
  2. A macOS Swift script loads page 1 with `loadFileURL(_:allowingReadAccessTo: /)`, waits for the fonts as Step 3 does, and writes `pdf(configuration:)` to `/tmp/duoscore-print/page-1.pdf`.
  3. `sips -s format png` turns that PDF into a PNG, which you then look at.

  Expected: a 595 × 842 pt page showing the title, the tuning, the tempo, notation over tab with Bravura glyphs (no boxes or letters in their place), and "1 / N". Delete the temporary test afterwards.
- [ ] **Step 6: Commit** `feat(ios): render page documents to PDF and share files`

---

### Task 3: The song exporter

**Files:**
- Create: `lib/features/export/song_exporter.dart`, `test/unit/features/export/song_exporter_test.dart`
- Modify: `lib/engine/protocol.dart`, `lib/engine/engine_bridge.dart`, `lib/core/dependency_injection.dart`, `test/unit/engine/engine_bridge_test.dart`

**Interfaces:**
- Consumes: Task 1's `exportPdf`, and Task 2's `ExportChannel`.
- Produces:
  - **Protocol:** `class PdfPages { final List<String> pages; final String baseUrl; }` with `fromJson`.
  - **Bridge:**
    - `EngineBridge.exportPdf(): Future<PdfPages>`, with a 60 s timeout;
    - `_request` gains an optional `Duration? timeout`.
  - **Exporter:**
    - `enum ExportFormat { gp, pdf }`;
    - `class SongExporter({required EngineBridge engine, required ScoreCubit score, required ExportChannel channel, required Directory temporary})`;
    - `Future<void> share(ExportFormat format, Rect anchor)`;
    - `static String fileName(String title, String extension)`.

    It is registered in get_it with `getTemporaryDirectory()`.

- [ ] **Step 1: Write the failing tests:**
  - **`song_exporter_test.dart`**, with mocktail fakes for the engine and the channel, and a temp directory:
    - `a .gp export writes the engine's bytes as <title>.gp and shares it`, with the anchor passed through;
    - `a PDF export renders the engine's pages into <title>.pdf and shares it`;
    - `file names replace / \ : and fall back to Untitled`: `AC/DC: Back` gives `AC-DC- Back.gp`, and `'  '` gives `Untitled.pdf`;
    - `each export clears the previous exports`;
    - `a failed PDF shares nothing`: when `makePdf` throws, `share` is never called and the error propagates.
  - **`engine_bridge_test.dart`:**
    - `exportPdf waits up to a minute`: with fakeAsync, a reply after 40 s completes, and none by 61 s throws `EngineTimeout('exportPdf')`;
    - `exportPdf reads the pages and base URL`.
- [ ] **Step 2: Run them to verify they fail:** `flutter test test/unit/features/export test/unit/engine/engine_bridge_test.dart`. Expected: FAIL, with `song_exporter.dart` missing.
- [ ] **Step 3: Implement,** then register `SongExporter` in `setupDependencies`.
- [ ] **Step 4: Run** `flutter test && flutter analyze`. Expected: all pass, and no issues.
- [ ] **Step 5: Commit** `feat: export the song as .gp or PDF`

---

### Task 4: The Export button

**Files:**
- Create: `lib/features/export/export_button.dart`, `test/widget/export/export_button_test.dart`
- Modify: `lib/features/score/score_page.dart`, `lib/main.dart`, `lib/l10n/app_en.arb`, `test/widget/score/score_page_test.dart`

**Interfaces:**
- Consumes: Task 3's `ExportFormat` and `SongExporter.share`.
- Produces:
  - `ExportButton({required Future<void> Function(ExportFormat format, Rect anchor) onExport, required bool canExportPdf})`;
  - `ScorePage` gains `final Future<void> Function(ExportFormat, Rect)? onExport`. When a song is open and `onExport` is set, the title row shows the button.
  - `main.dart` builds `ScorePage(onExport: getIt<SongExporter>().share)`.
- l10n:
  - `export`: "Export";
  - `exportGp`: "Guitar Pro file (.gp)";
  - `exportPdf`: "PDF";
  - `exportFailed`: "Couldn't export: {error}".

- [ ] **Step 1: Write the failing tests:**
  - **`export_button_test.dart`:**
    - `the menu offers .gp and PDF`;
    - `PDF is disabled without a guitar track`: with `canExportPdf: false`, tapping PDF calls nothing;
    - `choosing a format exports with the button's rect`: the rect equals the button's global paint bounds, and it isn't empty;
    - `the button is disabled while an export runs`: while `onExport`'s future is pending, a second tap opens no menu and a progress indicator shows;
    - `a failed export shows the error`: a SnackBar contains "Couldn't export".
  - **`score_page_test.dart`:** `the export button shows beside the title when a song is open`.
- [ ] **Step 2: Run them to verify they fail:** `flutter test test/widget/export test/widget/score/score_page_test.dart`. Expected: FAIL, with `export_button.dart` missing.
- [ ] **Step 3: Implement.** Add the arb keys, then run `flutter gen-l10n`. `canExportPdf` is `song.guitarTracks.isNotEmpty`.
- [ ] **Step 4: Run the checks:**
  ```
  npm --prefix engine run build && flutter test && flutter analyze \
    && flutter build ios --simulator \
    && xcrun simctl install booted build/ios/iphonesimulator/Runner.app \
    && xcrun simctl launch booted dev.edbrsk.duoscore
  ```
  Expected: all pass, no issues, and the app launches.
- [ ] **Step 5: Commit** `feat: Export button beside the song title`

---

## Owner checks on the simulator

1. **Export → Guitar Pro file:** the share sheet opens from the button. Save to Files, then open the file in Guitar Pro 8: it matches the song, edits and tones included.
2. **Export → PDF of Collateral Damage:**
   - the preview shows the title, the E♭ tuning and the tempo, with notation over tab;
   - there is one track on numbered A4 pages, with no system cut across a page.
3. **Hide the tab staff in the track panel and export a PDF again:** it shows notation only.
4. **Export a song with no guitar track:** PDF is greyed out, and `.gp` works.
