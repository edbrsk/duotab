/** Stored 0–1 values; a track without a channel strip is null. */
export type GpMixer = { tracks: ({ volume: number; pan: number } | null)[]; master: number | null };

/**
 * The mixer of a Guitar Pro 7/8 file, read from its `score.gpif`: alphaTab
 * floors track levels to sixteenths and ignores the master. Null for any
 * other file.
 */
export async function readGpMixer(bytes: Uint8Array): Promise<GpMixer | null> {
  const gpif = await zipEntry(bytes, 'Content/score.gpif');
  if (gpif === null) return null;
  const master = /<MasterTrack>([\s\S]*?)<\/MasterTrack>/.exec(gpif)?.[1] ?? '';
  const order = (/<Tracks>([^<]*)<\/Tracks>/.exec(master)?.[1] ?? '').trim().split(/\s+/).filter(Boolean);
  const strips = new Map<string, { volume: number; pan: number }>();
  for (const [, id, body] of gpif.matchAll(/<Track id="(\d+)"[^>]*?(?:\/>|>([\s\S]*?)<\/Track>)/g)) {
    const strip = /<ChannelStrip(?:\s[^>]*)?(?<!\/)>([\s\S]*?)<\/ChannelStrip>/.exec(body ?? '')?.[1] ?? '';
    const values = /<Parameters>([^<]*)<\/Parameters>/.exec(strip)?.[1].trim().split(/\s+/).map(Number);
    if (values && Number.isFinite(values[11]) && Number.isFinite(values[12])) strips.set(id, { volume: values[12], pan: values[11] });
  }
  const masterVolume = Number(/<Effect id="I01_VolumeAndPan">[\s\S]*?<Parameters>([^<]*)<\/Parameters>/.exec(master)?.[1].trim().split(/\s+/)[0]);
  return {
    tracks: order.map((id) => strips.get(id) ?? null),
    master: Number.isFinite(masterVolume) ? masterVolume : null,
  };
}

async function zipEntry(bytes: Uint8Array, name: string): Promise<string | null> {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = -1;
  for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 0xffff - 22); i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      end = i;
      break;
    }
  }
  if (end < 0) return null;
  const count = view.getUint16(end + 10, true);
  let at = view.getUint32(end + 16, true);
  const decoder = new TextDecoder();
  for (let n = 0; n < count && at + 46 <= bytes.length; n++) {
    if (view.getUint32(at, true) !== 0x02014b50) return null;
    const method = view.getUint16(at + 10, true);
    const size = view.getUint32(at + 20, true);
    const nameLength = view.getUint16(at + 28, true);
    const local = view.getUint32(at + 42, true);
    const entry = decoder.decode(bytes.subarray(at + 46, at + 46 + nameLength));
    at += 46 + nameLength + view.getUint16(at + 30, true) + view.getUint16(at + 32, true);
    if (entry !== name) continue;
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    const data = bytes.subarray(start, start + size);
    if (method === 0) return decoder.decode(data);
    if (method !== 8) return null;
    const inflated = new Blob([new Uint8Array(data)]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
    return decoder.decode(await new Response(inflated).arrayBuffer());
  }
  return null;
}
