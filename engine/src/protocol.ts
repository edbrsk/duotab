// Mirrored by hand in lib/engine/protocol.dart: change both together.

export type RequestType = 'ping' | 'summarize' | 'open' | 'renderTrack' | 'play' | 'pause' | 'stop';

export type Request = { id: number; type: RequestType; payload: unknown };

export type Reply =
  | { id: number; ok: true; payload: unknown }
  | { id: number; ok: false; error: string };

export type EventType = 'ready' | 'rendered' | 'error' | 'playerState';

export type EngineEvent = { event: EventType; payload: unknown };

/** `summarize` and `open` take a path relative to the app's Documents folder. */
export type PathPayload = { path: string };

export type RenderTrackPayload = { index: number };

export type PlayerStatePayload = { playing: boolean };

export type TrackKind = 'guitar' | 'drums' | 'other';

export type TrackSummary = {
  index: number;
  name: string;
  kind: TrackKind;
  stringCount: number | null;
  /** MIDI note numbers of the open strings, top string first. */
  tuning: number[] | null;
  /** 0-based General MIDI program, as alphaTab stores it. */
  midiProgram: number;
};

export type SongSummary = { title: string; tracks: TrackSummary[] };
