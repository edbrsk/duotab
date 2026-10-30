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
