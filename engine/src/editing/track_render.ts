import type { EditCommand } from '../protocol';

type TrackRenderApi = {
  readonly score: { tracks: unknown[] } | null;
  renderTracks(tracks: never[]): void;
  loadMidiForScore(): void;
};

/**
 * Draws the drawn track after a track edit. alphaTab loads no MIDI when it
 * renders the score it already has, so the new track list is loaded here.
 */
export async function drawAfterTrackEdit(
  api: TrackRenderApi,
  mixer: { regenerate(load: () => void): Promise<void> },
  track: number,
  op: EditCommand['op'],
): Promise<void> {
  const drawn = api.score!.tracks[track] as never;
  if (op === 'renameTrack') {
    api.renderTracks([drawn]);
    return;
  }
  await mixer.regenerate(() => {
    api.renderTracks([drawn]);
    api.loadMidiForScore();
  });
}
