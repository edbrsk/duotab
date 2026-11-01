# DuoScore: Song | Track panel

**Status:** approved by the owner (mockups `song-track-tabs.html` and `panel-split.html` in the visual companion, and in chat).
**Extends:** `2026-10-29-duoscore-design.md` (layout, track panel) and `2026-11-01-duoscore-chords-design.md` (the input part).

## Why

The upper part of the right panel mixes the track's settings with things that belong to the song, and spends a lot of height: tone as three radio rows, notation as chips whose labels get cut off. Guitar Pro splits its panel into **Song** and **Track**; the owner wants the same split, with only what DuoScore can actually do. The row above the sheet (title ✎ and export) repeats the title the sheet already prints.

## What changes

The right panel keeps the two parts built on `panel-split`: the upper part over the **Input** part (Frets | Chords and the shared ◀ ▲ ▼ ▶ row), each scrolling on its own and folding to its header. Only the upper part changes.

### Upper part header

- A **Song | Track** switch replaces the track-name header, with the fold chevron at its end.
- The chosen tab is remembered across launches, like the Frets | Chords choice. Default: Track.
- Folded, the header still shows the switch. Tapping a tab while folded unfolds the part on that tab.

### Track tab

In this order:

1. **Information:** the track name, tapped to rename (the existing dialog).
2. **Musical notation:**
   - Four view keys in one row: **Standard**, **Tab**, **Slash**, **Numbered** (Guitar Pro's four, which alphaTab draws). Slash and Numbered add to the others; **Standard or Tab always stays on**, since the cursor and taps work on those two staves (builder's call, checked against `hit_test.ts`). So the last of Standard and Tab can't be turned off. Short labels shrink to fit; each key's tooltip has the full name.
   - The tuning and string count on one line (`E A D G B E · 6 strings`), with **Retune…** and the retune report card below it, as now.
3. **Tone:** a dropdown with the three tones (as the default tone in Settings), replacing the radio rows.

Not included: Guitar Pro's Sounds section (DuoScore's tone choice covers it) and Interpretation (playing style, palm mute, accentuation, auto let ring, auto brush, stringed). alphaTab neither plays nor keeps those, so the owner chose to leave them out.

### Song tab

1. **Information:** **Title** and **Artist** as text fields, edited in place.
   - A change is saved when the field is submitted or loses focus, as one undoable edit, like the title change today.
   - An empty title isn't saved; the field goes back to the current title. An empty artist is allowed and clears it.
   - A field left unchanged saves nothing. A song without a title of its own shows its file name in the field, as DuoScore shows it today, and stays untitled until the owner types one; the sheet prints no title for it (builder's call).
   - alphaTab prints the title and artist at the top of the sheet.
2. **Export:** the existing export button (`.gp` and PDF, PDF only with a guitar track).

Not included: Guitar Pro's song-level musical notation (concert tone, stylesheet), which doesn't apply to guitar tab.

### The row above the sheet

The title row goes. The sheet shows the title (and artist) itself; editing moves to the Song tab, export to the Song tab.

- **Split View without a vertical bar:** the play-only ☰ button, which sat in that row, floats at the top end of the sheet instead.

### Play-only panel (☰, on the closed phone and in Split View)

It gets the same **Song | Track** tabs, without folding and without the Input part.

- **Song tab:** title and artist as plain text, and the export button.
- **Track tab:** the name as text; the four view keys and the tone dropdown, which work as today in play-only; the tuning line without Retune.

## Where things are kept

- **Views:** as today, DuoScore's own per-song record (`TrackPractice` in the practice store), now with slash and numbered as well. Opening a song shows standard and tab, slash and numbered off, until the owner changes them, as today. Because the views are set on the song's staves, a saved `.gp` carries them, as notation and tab already are.
- **Artist:** in the song itself (`score.artist`), which Guitar Pro reads and writes.
- **Tab and fold choices:** app settings, beside `chordsShown`.

## Left to the builder

- The view keys' icons or labels, as long as all four fit the 240 pt panel at the owner's larger text size without wrapping.
- The fields' exact styling, matching the dark panel.
- How the floating ☰ avoids covering the sheet's title.
