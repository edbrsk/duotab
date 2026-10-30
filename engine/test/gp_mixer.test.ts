import * as alphaTab from '@coderline/alphatab';
import { expect, test } from 'vitest';

import { readGpMixer } from '../src/gp_mixer';
import { score, twoGuitarsAndDrums } from './fixtures';

/** A zip holding `name` uncompressed, as a test can write one by hand. */
function storedZip(name: string, content: string): Uint8Array {
  const file = new TextEncoder().encode(name);
  const data = new TextEncoder().encode(content);
  const local = new Uint8Array(30 + file.length + data.length);
  const lv = new DataView(local.buffer);
  lv.setUint32(0, 0x04034b50, true);
  lv.setUint32(18, data.length, true);
  lv.setUint32(22, data.length, true);
  lv.setUint16(26, file.length, true);
  local.set(file, 30);
  local.set(data, 30 + file.length);
  const central = new Uint8Array(46 + file.length);
  const cv = new DataView(central.buffer);
  cv.setUint32(0, 0x02014b50, true);
  cv.setUint32(20, data.length, true);
  cv.setUint32(24, data.length, true);
  cv.setUint16(28, file.length, true);
  cv.setUint32(42, 0, true);
  central.set(file, 46);
  const end = new Uint8Array(22);
  const ev = new DataView(end.buffer);
  ev.setUint32(0, 0x06054b50, true);
  ev.setUint16(8, 1, true);
  ev.setUint16(10, 1, true);
  ev.setUint32(12, central.length, true);
  ev.setUint32(16, local.length, true);
  const zip = new Uint8Array(local.length + central.length + end.length);
  zip.set(local, 0);
  zip.set(central, local.length);
  zip.set(end, local.length + central.length);
  return zip;
}

test('reads track volume and pan from a file alphaTab wrote', async () => {
  const s = score(twoGuitarsAndDrums);
  s.tracks[0].playbackInfo.volume = 10.88;
  s.tracks[0].playbackInfo.balance = 0;
  s.tracks[1].playbackInfo.volume = 12;
  const mixer = await readGpMixer(new alphaTab.exporter.Gp7Exporter().export(s, new alphaTab.Settings()));
  expect(mixer!.tracks).toHaveLength(3);
  expect(mixer!.tracks[0]!.volume).toBeCloseTo(0.68, 6);
  expect(mixer!.tracks[0]!.pan).toBeCloseTo(0, 6);
  expect(mixer!.tracks[1]!.volume).toBeCloseTo(0.75, 6);
  expect(mixer!.tracks[1]!.pan).toBeCloseTo(0.5, 6);
  expect(mixer!.master).toBeNull();
});

test("reads the master from Guitar Pro's mixer", async () => {
  const gpif = `<GPIF><MasterTrack><Tracks>0</Tracks><RSE><Master>
<Effect id="I01_VolumeAndPan"><Parameters>0.61 0.5</Parameters></Effect></Master></RSE></MasterTrack>
<Tracks><Track id="0"><Name><![CDATA[Guitar 1]]></Name><RSE><ChannelStrip version="E56">
<Parameters>0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5 0 0.5 0.5 0.795 0.5 0.5 0.5</Parameters></ChannelStrip></RSE></Track></Tracks></GPIF>`;
  const mixer = await readGpMixer(storedZip('Content/score.gpif', gpif));
  expect(mixer!.master).toBeCloseTo(0.61, 6);
  expect(mixer!.tracks[0]!.volume).toBeCloseTo(0.795, 6);
  expect(mixer!.tracks[0]!.pan).toBeCloseTo(0.5, 6);
});

test('anything else reads nothing', async () => {
  expect(await readGpMixer(new TextEncoder().encode('<score-partwise/>'))).toBeNull();
});
