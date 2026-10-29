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

export function gpBytes(alphaTex: string): Uint8Array {
  const settings = new alphaTab.Settings();
  const importer = new alphaTab.importer.AlphaTexImporter();
  importer.initFromString(alphaTex, settings);
  return new alphaTab.exporter.Gp7Exporter().export(importer.readScore(), settings);
}
