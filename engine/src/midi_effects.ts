import * as alphaTab from '@coderline/alphatab';

type Note = alphaTab.model.Note;
type Beat = alphaTab.model.Beat;
type NoteDuration = { noteOnly: number; untilTieOrSlideEnd: number; letRingEnd: number };
type AddNote = (track: number, start: number, length: number, key: number, velocity: number, channel: number) => void;
type AddNoteBend = (track: number, tick: number, channel: number, key: number, value: number) => void;
type AddBend = (track: number, tick: number, channel: number, value: number) => void;

// The parts of alphaTab 1.6.1's MidiFileGenerator that play a note (unchanged in 1.8.4).
type Generator = {
  _handler: { addNote: AddNote; addNoteBend: AddNoteBend; addBend: AddBend };
  determineChannel(track: alphaTab.model.Track, note: Note): number;
  generateNote(note: Note, beatStart: number, beatDuration: number, tempo: number, ...rest: unknown[]): void;
  generateTremoloPicking(note: Note, start: number, duration: NoteDuration, key: number, velocity: number, channel: number): void;
  generateBend(note: Note, start: number, duration: NoteDuration, key: number, channel: number, tempo: number): void;
  generateWhammy(beat: Beat, start: number, duration: NoteDuration, channel: number, tempo: number): void;
  generateSlide(note: Note, start: number, duration: NoteDuration, key: number, channel: number, tempo: number): void;
  generateVibrato(note: Note, start: number, duration: NoteDuration, key: number, channel: number): void;
};

const CENTRE = 8192;
const patched = new WeakSet<object>();
const tempos = new WeakMap<object, number>();
// Where each channel's pitch wheel was last left, per MIDI handler.
const wheels = new WeakMap<object, Map<number, number>>();

/**
 * Makes `generator` play a tremolo-picked note's bend, whammy, slide and
 * vibrato, which alphaTab skips, and pick a tied tremolo note once. It plays
 * a whammy from its first point once: alphaTab sets that point both on the
 * channel and on the note, and the synth adds the two. A note without a
 * whammy starts with the channel unbent, which alphaTab leaves where the last
 * whammy ended.
 */
export function playEffectsUnderTremolo(generator: typeof alphaTab.midi.MidiFileGenerator): void {
  const proto = generator.prototype as unknown as Generator;
  if (patched.has(proto)) return;
  patched.add(proto);
  const { generateNote, generateTremoloPicking } = proto;

  proto.generateNote = function (this: Generator, note, beatStart, beatDuration, tempo, ...rest) {
    tempos.set(this, tempo);
    const wheel = wheelOf(this._handler);
    if (!note.beat.hasWhammyBar && !note.isTieDestination) unbend(this, wheel, note, beatStart);
    if (note.hasBend || !note.beat.hasWhammyBar) {
      generateNote.call(this, note, beatStart, beatDuration, tempo, ...rest);
      return;
    }
    const handler = this._handler;
    const addNoteBend = handler.addNoteBend;
    let initial = true;
    // The note's first pitch message is its starting pitch; the whammy sets it on the channel.
    handler.addNoteBend = function (track, tick, channel, key, value) {
      if (!initial) addNoteBend.call(this, track, tick, channel, key, value);
      else if (!note.isTieDestination) addNoteBend.call(this, track, tick, channel, key, CENTRE);
      initial = false;
    };
    try {
      generateNote.call(this, note, beatStart, beatDuration, tempo, ...rest);
    } finally {
      handler.addNoteBend = addNoteBend;
    }
  };

  proto.generateTremoloPicking = function (this: Generator, note, start, duration, key, velocity, channel) {
    const handler = this._handler;
    const strikes: number[] = [];
    const addNote = handler.addNote;
    handler.addNote = function (track, tick, ...rest) {
      strikes.push(tick);
      addNote.call(this, track, tick, ...rest);
    };
    // alphaTab picks a tied note through the whole tie, and a tied note that is
    // tremolo-picked too picks itself again, so the strikes would stack.
    const picked = note.tieDestination?.beat.isTremolo ? { ...duration, untilTieOrSlideEnd: duration.noteOnly } : duration;
    try {
      generateTremoloPicking.call(this, note, start, picked, key, velocity, channel);
    } finally {
      handler.addNote = addNote;
    }

    const bends: [tick: number, value: number][] = [];
    const addNoteBend = handler.addNoteBend;
    handler.addNoteBend = function (track, tick, channel, key, value) {
      bends.push([tick, value]);
      addNoteBend.call(this, track, tick, channel, key, value);
    };
    try {
      playEffects(this, note, start, duration, key, channel, tempos.get(this)!);
    } finally {
      handler.addNoteBend = addNoteBend;
    }

    // A note-off clears the note's own pitch, so each strike takes back the bend reached by then.
    const track = note.beat.voice.bar.staff.track.index;
    for (const tick of strikes.slice(1)) {
      let reached: number | undefined;
      for (const [at, value] of bends) if (at <= tick) reached = value;
      if (reached !== undefined) addNoteBend.call(handler, track, tick, channel, key, reached);
    }
  };
}

/** The effects alphaTab plays on a note that isn't tremolo-picked, in its order. */
function playEffects(g: Generator, note: Note, start: number, duration: NoteDuration, key: number, channel: number, tempo: number) {
  if (note.hasBend) g.generateBend(note, start, duration, key, channel, tempo);
  else if (note.beat.hasWhammyBar && note.index === 0) g.generateWhammy(note.beat, start, duration, channel, tempo);
  else if (note.slideInType !== alphaTab.model.SlideInType.None || note.slideOutType !== alphaTab.model.SlideOutType.None) {
    g.generateSlide(note, start, duration, key, channel, tempo);
  } else if (
    note.vibrato !== alphaTab.model.VibratoType.None ||
    (note.isTieDestination && note.tieOrigin!.vibrato !== alphaTab.model.VibratoType.None)
  ) {
    g.generateVibrato(note, start, duration, key, channel);
  }
}

function wheelOf(handler: Generator['_handler']): Map<number, number> {
  let wheel = wheels.get(handler);
  if (!wheel) {
    const known = new Map<number, number>();
    wheels.set(handler, (wheel = known));
    const addBend = handler.addBend;
    handler.addBend = function (track, tick, channel, value) {
      known.set(channel, value);
      addBend.call(this, track, tick, channel, value);
    };
  }
  return wheel;
}

function unbend(g: Generator, wheel: Map<number, number>, note: Note, tick: number) {
  const handler = g._handler;
  const track = note.beat.voice.bar.staff.track;
  const channel = g.determineChannel(track, note);
  if ((wheel.get(channel) ?? CENTRE) !== CENTRE) handler.addBend(track.index, tick, channel, CENTRE);
}

/**
 * Moves bends, whammy, slides and vibrato in steps of about 3 cents every 10 ms
 * or less. alphaTab steps a sixth of a semitone at a time, which a held note
 * plays as an audible staircase.
 */
export function glideFinely(generator: typeof alphaTab.midi.MidiFileGenerator): void {
  const steps = generator as unknown as { MinBreakpointsPerSemitone: number; MillisecondsPerBreakpoint: number };
  steps.MinBreakpointsPerSemitone = 32;
  steps.MillisecondsPerBreakpoint = 10;
}

/**
 * Starts every channel unbent. Stopping keeps the synth's channels as they
 * were, and alphaTab's start of song sets no pitch, so playing again after
 * stopping mid-dive would start at the dive's pitch.
 */
export function startChannelsUnbent(generator: typeof alphaTab.midi.MidiFileGenerator): void {
  const proto = generator.prototype as unknown as {
    _handler: { addBend: AddBend };
    generateChannel(track: alphaTab.model.Track, channel: number, playbackInfo: unknown): void;
  };
  const { generateChannel } = proto;
  proto.generateChannel = function (track, channel, playbackInfo) {
    generateChannel.call(this, track, channel, playbackInfo);
    this._handler.addBend(track.index, 0, channel, CENTRE);
  };
}
