// Mirrored by hand in lib/engine/protocol.dart: change both together.

export type RequestType = 'ping' | 'summarize' | 'open' | 'renderTrack' | 'play' | 'pause' | 'stop' | 'seekBar' | 'setTracks' | 'setSpeed' | 'setLooping' | 'setRange' | 'setPlayerOptions' | 'setStaves' | 'edit' | 'undo' | 'redo' | 'newSong' | 'exportGp';

export type Request = { id: number; type: RequestType; payload: unknown };

export type Reply =
  | { id: number; ok: true; payload: unknown }
  | { id: number; ok: false; error: string };

export type EventType = 'ready' | 'rendered' | 'error' | 'playerState' | 'position' | 'rangeChanged' | 'tapped';

export type EngineEvent = { event: EventType; payload: unknown };

/** `summarize` and `open` take a path relative to the app's Documents folder. */
export type PathPayload = { path: string };

export type RenderTrackPayload = { index: number };

export type PlayerStatePayload = { playing: boolean };

export type SeekBarPayload = { bar: number };

/** `volume`: 0–16, Guitar Pro's track volume. */
export type TrackMix = { index: number; mute: boolean; solo: boolean; program: number; volume: number };

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
  /** 0–16. */
  volume: number;
  /** The primary MIDI channel, which tells the track apart when tracks move. */
  channel: number;
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

/** A voice whose notes and rests don't add up to its bar; negative `ticksOff` means short. */
export type BarIssue = { bar: number; voice: number; ticksOff: number };

export type NewSongOptions = {
  title: string;
  /** MIDI note numbers of the open strings, top string first. */
  tuning: number[];
  tempo: number;
  numerator: number;
  denominator: number;
};

export type TechniqueId =
  | 'hammerPull'
  | 'slide'
  | 'bend'
  | 'vibrato'
  | 'palmMute'
  | 'letRing'
  | 'deadNote'
  | 'ghostNote'
  | 'naturalHarmonic'
  | 'artificialHarmonic'
  | 'tie'
  | 'accent'
  | 'marcato'
  | 'tenuto'
  | 'staccato'
  | 'doubleFlat'
  | 'flat'
  | 'natural'
  | 'sharp'
  | 'doubleSharp'
  | 'tapping'
  | 'pickUp'
  | 'pickDown'
  | 'tremolo'
  | 'fermata'
  | 'crescendo'
  | 'diminuendo';

export type Dynamic = 'ppp' | 'pp' | 'p' | 'mp' | 'mf' | 'f' | 'ff' | 'fff';

/** 1 is no tuplet; 3, 5 and 6 are 3:2, 5:4 and 6:4. */
export type Tuplet = 1 | 3 | 5 | 6;

export type BendKind = 'bend' | 'bendRelease' | 'prebend' | 'prebendRelease';

/** `amount` in quarter tones: 1 is ¼ tone, 4 a full bend, 12 three tones. */
export type Bend = { kind: BendKind; amount: number };

export type Clef = 'treble' | 'bass';

export type BarProperties = {
  numerator: number;
  denominator: number;
  /** −7 (seven flats) to 7 (seven sharps). */
  key: number;
  minor: boolean;
  /** Null for a clef the palette doesn't offer. */
  clef: Clef | null;
  /** In force at the bar's start. */
  tempo: number;
  /** The bar has its own tempo marking; always true for the first bar. */
  tempoChange: boolean;
};

export type DirectionId =
  | 'segno'
  | 'coda'
  | 'fine'
  | 'daCapo'
  | 'daCapoAlFine'
  | 'daCapoAlCoda'
  | 'dalSegno'
  | 'dalSegnoAlFine'
  | 'dalSegnoAlCoda'
  | 'toCoda';

export type Structure = {
  repeatStart: boolean;
  /** How many times the repeat plays; 0 when the bar ends no repeat. */
  repeatCount: number;
  /** Ascending, 1–8. */
  endings: number[];
  directions: DirectionId[];
};

export type EditCommand =
  | { op: 'setFret'; fret: number }
  | { op: 'deleteNote' }
  | { op: 'setDuration'; duration: number; dots: number }
  | { op: 'setRest' }
  | { op: 'selectVoice'; voice: number }
  | { op: 'move'; direction: 'left' | 'right' | 'up' | 'down' }
  | { op: 'place'; position: EditPosition }
  | { op: 'toggle'; technique: TechniqueId }
  | { op: 'setDynamic'; dynamic: Dynamic }
  | { op: 'setTuplet'; tuplet: Tuplet }
  | { op: 'addGrace' }
  | { op: 'setBend'; bend: Bend | null }
  /** Needs no cursor. */
  | { op: 'setTitle'; title: string }
  | { op: 'setTimeSignature'; numerator: number; denominator: number }
  /** Null removes the bar's tempo marking. */
  | { op: 'setTempo'; bpm: number | null }
  | { op: 'setKeySignature'; key: number; minor: boolean }
  | { op: 'setClef'; clef: Clef }
  | { op: 'insertBar' }
  | { op: 'deleteBar' }
  /** The loop's bars when the cursor is inside the loop, else the cursor bar. */
  | { op: 'copyBars' }
  | { op: 'pasteBars' }
  | { op: 'toggleRepeatStart' }
  /** `count` plays; 0 removes the repeat end. */
  | { op: 'setRepeatEnd'; count: number }
  /** Adds or removes one ending, 1–8. */
  | { op: 'toggleEnding'; ending: number }
  | { op: 'toggleDirection'; direction: DirectionId };

export type EditPayload = { command: EditCommand };

/** The reply to `edit`, `undo` and `redo`; `edited` is true when the song changed. */
export type EditState = {
  /** Null until the owner taps a string. */
  position: EditPosition | null;
  issues: BarIssue[];
  canUndo: boolean;
  canRedo: boolean;
  song: SongSummary;
  edited: boolean;
  /** The beat under the cursor, which the palette shows. */
  beat: {
    duration: number;
    dots: number;
    /** Beat techniques, and the note techniques of the cursor string's note. */
    techniques: TechniqueId[];
    /** Null for a dynamic the palette doesn't offer. */
    dynamic: Dynamic | null;
    tuplet: Tuplet;
    /** The cursor string has a note, so note techniques apply. */
    hasNote: boolean;
    /** Null also for a bend shape outside the four kinds. */
    bend: Bend | null;
  } | null;
  /** Null without a cursor. */
  bar: BarProperties | null;
  /** Null without a cursor. */
  structure: Structure | null;
  canPaste: boolean;
};

/** Posted for a tap on the drawn track. */
export type TappedPayload = { position: EditPosition };

export type ExportGpReply = { base64: string };
