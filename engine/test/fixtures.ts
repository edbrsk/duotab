import * as alphaTab from '@coderline/alphatab';

export const twoGuitarsAndDrums = String.raw`\title "Fixture"
.
\track "Guitar 1" \instrument 29 \tuning E4 B3 G3 D3 A2 E2
0.6.4 2.5.4 | 3.4.2
\track "Seven" \tuning E4 B3 G3 D3 A2 E2 B1
0.7.1
\track "Drums" \instrument percussion
\articulation defaults
42.4 | 36.1`;

export const tempoAndSections = String.raw`\title "Timeline"
\tempo 120
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\section "A" "Intro" 0.6.4*4 | \tempo 60 0.6.4*4 | \section "B" "Verse" r.1 | 3.5.1`;

export const repeated = String.raw`\title "Repeat"
\tempo 120
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\ro 0.6.4*4 | \rc 2 2.6.4*4 | 3.5.1`;

export const fourQuarters = String.raw`\title "Edit"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\ts 4 4 0.6.4 2.5.4 3.4.4 r.4 | r.1`;

export const sixEight = String.raw`\title "Six"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
\ts 6 8 0.6.4{d} 2.5.4{d}`;

export const lineOfEighths = String.raw`\title "Line"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
5.3.8 7.3.8 5.3.8 7.3.8 5.3.4 5.3.4 | 0.6.4 0.6.4 0.6.4 0.6.4`;

export const twoTracksThreeBars = String.raw`\title "Bars"
\tempo 100
.
\track "A" \tuning E4 B3 G3 D3 A2 E2
\ts 4 4 0.6.4 2.6.4 3.6.4 5.6.4 | r.1 | r.1
\track "B" \tuning E4 B3 G3 D3 A2 E2
\ts 4 4 0.6.4 2.6.4 3.6.4 5.6.4 | r.1 | r.1`;

export const sixBars = String.raw`\title "Form"
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | 1.6.1 | 2.6.1 | 3.6.1 | 4.6.1 | 5.6.1`;

// alphaTex reads no tuning on a track after a percussion one, so drums come last.
export const guitarsAndDrums = String.raw`\title "Band"
.
\track "Guitar A" \tuning E4 B3 G3 D3 A2 E2
0.6.1 | \ts 3 4 3.6.2{d} | \ts 4 4 \ro \rc 2 5.6.1
\track "Guitar B" \tuning E4 B3 G3 D3 A2 E2 B1
0.7.1 | r.2{d} | r.1
\track "Drums" \instrument percussion
\articulation defaults
42.1 | 42.2{d} | 42.1`;

export function score(alphaTex: string): alphaTab.model.Score {
  const importer = new alphaTab.importer.AlphaTexImporter();
  importer.initFromString(alphaTex, new alphaTab.Settings());
  return importer.readScore();
}

export function gpBytes(alphaTex: string): Uint8Array {
  return new alphaTab.exporter.Gp7Exporter().export(score(alphaTex), new alphaTab.Settings());
}

export const longRiff = String.raw`\title "Riff" \tempo 140
.
\track "G" \tuning E4 B3 G3 D3 A2 E2
${Array.from({ length: 40 }, () => '0.6.4 2.5.4 3.4.4 5.3.4').join(' | ')}`;

export const pitchesOnly = String.raw`\title "Pitches"
.
\track "P" \instrument 25 \tuning piano
G3.4 A3.4 B3.4 C4.4 | E4.4 (E2 B3 E4).4 C5.4 D4.4 | C2.4 C7.4 F4.2 | F4{t}.1`;

/** A guitar part as MusicXML exporters often write it: pitches, no strings or frets. */
export const pitchOnlyXml = `<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Guitar</part-name>
<score-instrument id="P1-I1"><instrument-name>Guitar</instrument-name></score-instrument>
<midi-instrument id="P1-I1"><midi-channel>1</midi-channel><midi-program>26</midi-program></midi-instrument></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time>
<clef><sign>G</sign><line>2</line><clef-octave-change>-1</clef-octave-change></clef>
<transpose><diatonic>0</diatonic><chromatic>0</chromatic><octave-change>-1</octave-change></transpose></attributes>
<note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
<note><chord/><pitch><step>B</step><octave>3</octave></pitch><duration>1</duration><type>quarter</type></note>
<note><pitch><step>G</step><octave>3</octave></pitch><duration>2</duration><type>half</type></note>
<note><rest/><duration>1</duration><type>quarter</type></note>
</measure></part></score-partwise>`;
