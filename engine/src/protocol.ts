// Mirrored by hand in lib/engine/protocol.dart: change both together.

export type RequestType = 'ping' | 'summarize' | 'open' | 'renderTrack' | 'play' | 'pause' | 'stop' | 'seekBar' | 'setTracks' | 'setSpeed' | 'setLooping' | 'setRange' | 'setPlayerOptions' | 'setStaves';

export type Request = { id: number; type: RequestType; payload: unknown };

export type Reply =
  | { id: number; ok: true; payload: unknown }
  | { id: number; ok: false; error: string };

export type EventType = 'ready' | 'rendered' | 'error' | 'playerState' | 'position' | 'rangeChanged';

export type EngineEvent = { event: EventType; payload: unknown };

/** `summarize` and `open` take a path relative to the app's Documents folder. */
export type PathPayload = { path: string };

export type RenderTrackPayload = { index: number };

export type PlayerStatePayload = { playing: boolean };

export type SeekBarPayload = { bar: number };

export type TrackMix = { index: number; mute: boolean; solo: boolean; program: number };

export type SetTracksPayload = { tracks: TrackMix[] };

export type StaffView = { index: number; notation: boolean; tab: boolean };

export type SetStavesPayload = { staves: StaffView[] };

/** 0.25–1.5 of the written tempo. */
export type SetSpeedPayload = { speed: number };

export type SetLoopingPayload = { looping: boolean };

export type PlayerOptionsPayload = { countIn: boolean; metronome: boolean };

export type Range = { startTick: number; endTick: number };

/** Also the payload of `rangeChanged`. */
export type RangePayload = { range: Range | null };

/** Posted when the bar under the playback position changes, and after every seek. */
export type PositionPayload = { bar: number };

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
  /** Per bar; filled by `open`, empty from `summarize`. */
  barsWithNotes: boolean[];
};

export type Section = { marker: string; text: string };

/** Where the bar first plays, counting repeats. */
export type BarInfo = { index: number; startTick: number; startMs: number; tempo: number; section: Section | null };

export type SongSummary = {
  title: string;
  tracks: TrackSummary[];
  /** Filled by `open`, empty from `summarize`. */
  bars: BarInfo[];
};

/** alphaTab numbers strings from the lowest: string 1 is the lowest-pitched. */
export type EditPosition = { track: number; bar: number; voice: number; beat: number; string: number };
