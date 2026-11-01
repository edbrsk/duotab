# DuoScore Chords: Writing a Chord from Its Symbol

**Status:** design, awaiting the owner's review.
**Extends:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`, Editor.

## Why

The owner writes a melody fret by fret, then wants to put chords under or between it the way a lead sheet does: by name. Entering Cmaj7 or B7♭9 string by string means working out the shape first, and the shape depends on the track's tuning: Cmaj7 on a 6-string in standard E is fingered differently from Cmaj7 on a 6-string in drop B or on a 7-string. DuoScore should know the shapes for the tuning in front of it and offer the different places on the neck to play each chord.

## Goals

1. With the cursor on a beat, the owner builds a chord symbol by tapping (root, type, additions) and DuoScore writes all the chord's notes on that beat in one step.
2. For the chosen symbol, DuoScore offers playable positions worked out from the track's own tuning and string count, and the owner picks one.
3. The chord's name is drawn above the beat on the sheet and saved in the `.gp` file, so Guitar Pro shows it too.
4. A chord already written can be changed: another position, or another symbol.

## Non-goals

- How the chord sounds beyond its notes. It plays as the notes written on the beat, through the existing playback; no strumming patterns, arpeggios or rhythm presets.
- Naming chords the owner entered note by note (chord detection).
- Chord diagrams drawn at the top of the score, or beside the name on the sheet.
- Typing chord symbols with the keyboard (option B in the mockup).
- Chords on drum or other non-guitar tracks.
- Chords in the play-only layout (Split View and the closed phone), where editing is off.

## Anti-goals

- A position is offered that a hand can't play.
- A position doesn't contain the chord it's named for, or its lowest sounding note isn't the root (or the slash chord's bass).
- Writing a chord touches another beat, voice or track.
- A chord written can't be undone in one step.

## The owner's decisions

Mockup: `.superpowers/brainstorm/70270-1793536820/content/chord-picker.html`, option **A** chosen.

### The picker

- **Where:** the right-hand panel, where the fret pad is. A **Frets | Chords** switch above the pad swaps it for the chord picker; Frets is the default and the app remembers the last choice.
- **Built by tapping**, top to bottom:
  - **Root:** C, C♯, D, E♭, E, F, F♯, G, A♭, A, B♭, B.
  - **Type:** maj, m, 7, maj7, m7, m7♭5, dim7, aug, sus2, sus4, 6, 5.
  - **Add or alter:** ♭9, 9, ♯9, 11, ♯11, ♭13, 13, and /bass (a slash chord over another note, chosen from the same twelve roots).
  - **Readout:** the symbol as it builds (for example "Cmaj7"), with the track's tuning and string count under it.
  - **Positions:** a strip of chord diagrams for the symbol, each labelled with its starting fret ("Open", "Fret 3", "Fret 8"). Tapping one writes it.

### Chord tones

Intervals from the root, in semitones:

| Type | Tones | | Addition | Tone |
|---|---|---|---|---|
| maj | 0 4 7 | | ♭9 | 13 |
| m | 0 3 7 | | 9 | 14 |
| 7 | 0 4 7 10 | | ♯9 | 15 |
| maj7 | 0 4 7 11 | | 11 | 17 |
| m7 | 0 3 7 10 | | ♯11 | 18 |
| m7♭5 | 0 3 6 10 | | ♭13 | 20 |
| dim7 | 0 3 6 9 | | 13 | 21 |
| aug | 0 4 8 | | | |
| sus2 | 0 2 7 | | | |
| sus4 | 0 5 7 | | | |
| 6 | 0 4 7 9 | | | |
| 5 | 0 7 | | | |

- **An addition adds exactly its own tone;** nothing below it is implied. 7 + 13 holds 0 4 7 10 21.
- **A slash bass** adds its note as the lowest note, whether or not it is a chord tone.
- **The "5th"** that may be left out is the type's 7, or its 6 or 8 for m7♭5, dim7 and aug. A 5 chord, being only the root and the 5th, keeps both.
- **Octaves don't matter:** a tone can sound in any octave and be doubled.

### Names

Standard lead-sheet names when the extensions stack up from the 7th, brackets when they don't. The name is what the sheet and Guitar Pro show, and DuoScore reads its own names back into root, type and additions.

| Built from | Name |
|---|---|
| 7 + 9 | C9 |
| 7 + 9 + 13 | C13 |
| maj7 + 9 | Cmaj9 |
| m7 + 9 | Cm9 |
| 7 + 13, without the 9 | C7(13) |
| 7 + 11 | C7(11) |
| m7 + 11 | Cm7(11) |
| maj + 9 | Cadd9 |
| m + 9 | Cm(add9) |
| 6 + 9 | C6/9 |
| 7 + ♭9 | C7♭9 |
| 7 + ♭9 + ♯11 | C7(♭9♯11) |
| any of these over another bass | adds /E, /G… |

A stacked name needs the 9 under it: C11 is 7 + 9 + 11, and C13 is 7 + 9 + 13 (the 11 isn't needed, as guitarists leave it out of a 13 chord). With the 11 chosen as well, the name is C13(11). Without the 9, the extension goes in brackets, as in C7(11) and C7(13).

### Positions

- **Playable:**
  - every fretted note lies within four frets of the others (highest fret − lowest fret ≤ 3);
  - at most one note per string, and no fret above the track's highest fret (24);
  - **four fingers at most:** each fretted note needs a finger, except that the first finger may barre one unbroken run of strings at the shape's lowest fret and counts once. The run holds no open or unplayed string; strings in it that sound higher are fretted by other fingers. Other notes at that fret need fingers of their own. The thumb isn't used. B7♭9 as 7 x 7 8 7 8 is four fingers: a barre over the 4th to 2nd strings, one finger on the 6th, and two on the 8th fret.
  - Open strings are allowed in open position, where every fretted note is at the 4th fret or below. Strings not played are shown as ×, including one between played strings (as in 7 x 7 8 7 8); never more than one.
  - At least three notes, and at least as many as the chord's required tones; a 5 chord may be two.
- **Right notes:** every note belongs to the chord; the lowest sounding note is the root, or the bass of a slash chord; every chord tone is present, except the 5th, which a position may leave out. Shapes without the 5th are offered alongside full ones, as guitarists play them; no other tone is ever left out.
- **Which ones:** the best three at each place on the neck. Open position is one place; every other shape belongs to the place of its lowest fret. "Best" is fewest gaps, then most strings, then fewest fingers, then the smallest stretch.
  - A shape is left out when another plays the same frets on more strings with no more fingers and no wider stretch: the fuller one is as easy.
  - A shape twelve frets above another is left out: it's the same shape an octave higher.
- **Order:** open position first, then up the neck.
- **The track's own strings:** the tuning and string count come from the track. A 7- or 8-string's extra low strings are used when they help; a drop tuning gets its own shapes.
- **Nothing playable:** the strip says so instead of offering an impossible shape.

Examples a correct generator offers (low string first):

| Track | Chord | Includes |
|---|---|---|
| 6-string, E standard (E A D G B E) | Cmaj7 | x 3 2 0 0 0 · x 3 5 4 5 3 · 8 x 9 9 8 8 |
| 6-string, E standard | B7♭9 | x 2 1 2 1 2 · 7 x 7 8 7 8 |
| 6-string, drop B (B F♯ B E G♯ C♯) | Cmaj7 | 1 1 0 0 3 3 |

### Writing and changing a chord

- **Writing:** tapping a position replaces whatever notes the cursor's beat holds, in the cursor's voice, with the position's notes. The beat keeps its duration and the cursor stays on it, as after a typed fret. One Undo removes the whole chord.
- **Changing:** with the cursor on a beat that has a chord, the Chords picker shows that chord's symbol and highlights the position matching the beat's notes. Picking another position or building another symbol rewrites the beat the same way.
- **Chords from other files:** a name DuoScore can read back into root, type and additions shows in the picker as if built there. Any other name (for example "N.C." or "A7sus4") shows as plain text with nothing selected; building a symbol replaces it.
- **Editing its notes by hand:** the name stays above the beat, as in Guitar Pro.
- **On the sheet:** only the name, above the beat.

## Calls I made (the owner can overrule)

- **A beat whose notes are all deleted** loses its chord name: a rest carries no chord.
- **Retuning** keeps chord names as they are, in both retune modes. With **Keep the frets** the notes sound different and the name may no longer match; the owner renames it from the picker.
- **Capo:** frets are written as the fret pad writes them, so positions are worked out the same way the pad's frets are read.
- **Additions that clash** (9 with ♭9 or ♯9, 11 with ♯11, 13 with ♭13) replace each other.
- **The Frets | Chords switch** is remembered across launches, like the panels' collapsed state.

## Constraints

- **Everything that reads or changes a song runs in the engine** (main design, Editor). Working out positions for a symbol and a tuning, and writing a chord on a beat, are engine operations; Flutter draws the picker and sends the symbol and the chosen position.
- **alphaTab's model already holds chords:**
  - A `Chord` has a `name`, `firstFret`, and `strings` with one fret per string, ordered from the highest string to the lowest, with −1 for a string not played. It also has `barreFrets` and `showName`/`showDiagram` flags.
  - A staff keeps its chords by id, and a beat refers to one through `beat.chordId`.
- **alphaTab draws and saves it:** chord names above the beat (`NotationElement.EffectChordNames`), and diagrams at the top of the score (`NotationElement.ChordDiagrams`, which this feature leaves off). Its `.gp` writer saves each staff's chords and each beat's chord.
- **Tuning:** a staff's `tuning` lists its open strings as MIDI notes, highest string first. A track's highest fret is 24 by default (main design, Retuning).
- **Undo and redo** cover every edit (main design, Editor), and a chord is one edit.
- **Comments:** only a non-obvious why, one line where possible.

## Left to the builder

- Whether diagrams show a barre or fingering.
- Sizes and spacing in the picker, within the mockup and the panel's 240 pt width.
- How the picker shows that a chosen combination isn't a chord DuoScore can name (if any combination can't be).

## Acceptance

- In a 6-string track in E standard, with the cursor on a beat, Chords → C → maj7 shows Cmaj7 with positions including x 3 2 0 0 0, x 3 5 4 5 3 and 8 x 9 9 8 8, open position first. Tapping x 3 2 0 0 0 writes those five notes on the beat, the name Cmaj7 appears above it, and playback plays the chord.
- The same steps in a drop B track offer 1 1 0 0 3 3 among Cmaj7's positions.
- B7♭9 in E standard offers x 2 1 2 1 2.
- Every position offered for every root, type and addition is playable (span ≤ 3 frets, one note per string, within 24 frets, four fingers), holds only chord tones, has the root (or slash bass) as its lowest note, and lacks at most the 5th.
- Writing a chord replaces only the cursor's beat in the cursor's voice, and the cursor stays on that beat; Undo restores what was there.
- No position offered needs more than four fingers, counting a first-finger barre over one unbroken run at the shape's lowest fret as one. x 3 2 4 5 3 (Cmaj7, five fingers) is not offered.
- With the cursor on a beat holding a chord, the picker shows that symbol with its position highlighted; picking another position rewrites the beat.
- A song with chords saved by DuoScore opens in Guitar Pro 8 with the chord names over the same beats.
