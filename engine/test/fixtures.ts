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

export function score(alphaTex: string): alphaTab.model.Score {
  const importer = new alphaTab.importer.AlphaTexImporter();
  importer.initFromString(alphaTex, new alphaTab.Settings());
  return importer.readScore();
}

export function gpBytes(alphaTex: string): Uint8Array {
  return new alphaTab.exporter.Gp7Exporter().export(score(alphaTex), new alphaTab.Settings());
}
