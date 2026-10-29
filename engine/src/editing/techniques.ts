import * as alphaTab from '@coderline/alphatab';

import type { Dynamic, EditPosition, TechniqueId, Tuplet } from '../protocol';
import { idSource } from './ids';
import { beatOf, voiceOf } from './position';

const {
  AccentuationType,
  BendPoint,
  BendType,
  CrescendoType,
  Duration,
  DynamicValue,
  Fermata,
  FermataType,
  GraceType,
  HarmonicType,
  NoteAccidentalMode,
  PickStroke,
  SlideOutType,
  VibratoType,
} = alphaTab.model;
type Score = alphaTab.model.Score;
type Beat = alphaTab.model.Beat;
type Note = alphaTab.model.Note;

const defaultSettings = new alphaTab.Settings();

type Technique =
  | { level: 'note'; get(note: Note): boolean; set(note: Note, on: boolean): void }
  | { level: 'beat'; get(beat: Beat): boolean; set(beat: Beat, on: boolean): void };

// Techniques that share a field form an exclusive group: setting one value replaces the others.
const noteField = <T>(read: (n: Note) => T, write: (n: Note, value: T) => void, value: T, none: T): Technique => ({
  level: 'note',
  get: (n) => read(n) === value,
  set: (n, on) => write(n, on ? value : none),
});

const beatField = <T>(read: (b: Beat) => T, write: (b: Beat, value: T) => void, value: T, none: T): Technique => ({
  level: 'beat',
  get: (b) => read(b) === value,
  set: (b, on) => write(b, on ? value : none),
});

type NoteFlag = 'isPalmMute' | 'isLetRing' | 'isDead' | 'isGhost' | 'isStaccato';
const noteFlag = (key: NoteFlag): Technique => ({
  level: 'note',
  get: (n) => n[key],
  set: (n, on) => {
    n[key] = on;
  },
});

const accent = (value: alphaTab.model.AccentuationType) =>
  noteField((n) => n.accentuated, (n, v) => (n.accentuated = v), value, AccentuationType.None);

const accidental = (value: alphaTab.model.NoteAccidentalMode) =>
  noteField((n) => n.accidentalMode, (n, v) => (n.accidentalMode = v), value, NoteAccidentalMode.Default);

const harmonic = (type: alphaTab.model.HarmonicType, value: (n: Note) => number): Technique => ({
  level: 'note',
  get: (n) => n.harmonicType === type,
  set: (n, on) => {
    n.harmonicType = on ? type : HarmonicType.None;
    n.harmonicValue = on ? value(n) : 0;
  },
});

const pick = (value: alphaTab.model.PickStroke) =>
  beatField((b) => b.pickStroke, (b, v) => (b.pickStroke = v), value, PickStroke.None);

const crescendo = (value: alphaTab.model.CrescendoType) =>
  beatField((b) => b.crescendo, (b, v) => (b.crescendo = v), value, CrescendoType.None);

// alphaTab links these to their neighbour in score.finish, and only fills a
// link that is unset, so turning one off or on clears both ends.
const TECHNIQUES: Record<TechniqueId, Technique> = {
  hammerPull: {
    level: 'note',
    get: (n) => n.isHammerPullOrigin,
    set: (n, on) => {
      if (n.hammerPullDestination) n.hammerPullDestination.hammerPullOrigin = null;
      n.hammerPullDestination = null;
      n.isHammerPullOrigin = on;
    },
  },
  slide: {
    level: 'note',
    get: (n) => n.slideOutType === SlideOutType.Shift,
    set: (n, on) => {
      if (n.slideTarget) n.slideTarget.slideOrigin = null;
      n.slideTarget = null;
      n.slideOutType = on ? SlideOutType.Shift : SlideOutType.None;
    },
  },
  bend: {
    level: 'note',
    get: (n) => n.bendType === BendType.Bend,
    set: (n, on) => {
      n.bendPoints = null;
      n.maxBendPoint = null;
      n.bendType = on ? BendType.Bend : BendType.None;
      // A full bend, in quarter tones, as Guitar Pro's default.
      if (on) for (const [offset, value] of [[0, 0], [15, 4], [60, 4]]) n.addBendPoint(new BendPoint(offset, value));
    },
  },
  vibrato: noteField((n) => n.vibrato, (n, v) => (n.vibrato = v), VibratoType.Slight, VibratoType.None),
  palmMute: noteFlag('isPalmMute'),
  letRing: noteFlag('isLetRing'),
  deadNote: noteFlag('isDead'),
  ghostNote: noteFlag('isGhost'),
  naturalHarmonic: harmonic(HarmonicType.Natural, (n) => n.fret),
  artificialHarmonic: harmonic(HarmonicType.Artificial, () => 12),
  tie: {
    level: 'note',
    get: (n) => n.isTieDestination,
    set: (n, on) => {
      if (n.tieOrigin) n.tieOrigin.tieDestination = null;
      n.tieOrigin = null;
      n.isTieDestination = on;
    },
  },
  accent: accent(AccentuationType.Normal),
  marcato: accent(AccentuationType.Heavy),
  tenuto: accent(AccentuationType.Tenuto),
  staccato: noteFlag('isStaccato'),
  doubleFlat: accidental(NoteAccidentalMode.ForceDoubleFlat),
  flat: accidental(NoteAccidentalMode.ForceFlat),
  // A forced natural draws and saves as the default spelling, so natural only
  // takes off the other accidentals.
  natural: {
    level: 'note',
    get: () => false,
    set: (n) => {
      n.accidentalMode = NoteAccidentalMode.Default;
    },
  },
  sharp: accidental(NoteAccidentalMode.ForceSharp),
  doubleSharp: accidental(NoteAccidentalMode.ForceDoubleSharp),
  tapping: {
    level: 'beat',
    get: (b) => b.tap,
    set: (b, on) => {
      b.tap = on;
    },
  },
  pickUp: pick(PickStroke.Up),
  pickDown: pick(PickStroke.Down),
  tremolo: beatField((b) => b.tremoloSpeed, (b, v) => (b.tremoloSpeed = v), Duration.Sixteenth, null),
  fermata: {
    level: 'beat',
    get: (b) => b.fermata !== null,
    set: (b, on) => {
      // The bar holds fermatas by tick; score.finish copies them onto its beats.
      b.voice.bar.masterBar.fermata?.delete(b.playbackStart);
      b.fermata = null;
      if (on) {
        b.fermata = new Fermata();
        b.fermata.type = FermataType.Medium;
      }
    },
  },
  crescendo: crescendo(CrescendoType.Crescendo),
  diminuendo: crescendo(CrescendoType.Decrescendo),
};

const TECHNIQUE_IDS = Object.keys(TECHNIQUES) as TechniqueId[];

const noteAt = (beat: Beat, string: number) => beat.notes.find((n) => n.string === string);

/** A note technique on a string without a note changes nothing. */
export function toggleTechnique(score: Score, at: EditPosition, id: TechniqueId, settings = defaultSettings): EditPosition {
  const technique = TECHNIQUES[id];
  const beat = beatOf(score, at);
  if (technique.level === 'beat') {
    technique.set(beat, !technique.get(beat));
  } else {
    const note = noteAt(beat, at.string);
    if (!note) return at;
    technique.set(note, !technique.get(note));
  }
  score.finish(settings);
  return at;
}

export function activeTechniques(score: Score, at: EditPosition): TechniqueId[] {
  const beat = beatOf(score, at);
  const note = noteAt(beat, at.string);
  return TECHNIQUE_IDS.filter((id) => {
    const technique = TECHNIQUES[id];
    if (technique.level === 'beat') return technique.get(beat);
    return note !== undefined && technique.get(note);
  });
}

// In DynamicValue's order: PPP is 0 and FFF is 7.
const DYNAMICS: Dynamic[] = ['ppp', 'pp', 'p', 'mp', 'mf', 'f', 'ff', 'fff'];

/** Like a written dynamic, it holds over the following beats until the next change. */
export function setDynamic(score: Score, at: EditPosition, dynamic: Dynamic, settings = defaultSettings): EditPosition {
  const value = DynamicValue.PPP + DYNAMICS.indexOf(dynamic);
  let beat: Beat | null = beatOf(score, at);
  const old = beat.dynamics;
  if (old === value) return at;
  while (beat && beat.dynamics === old) {
    beat.dynamics = value;
    beat = beat.nextBeat;
  }
  score.finish(settings);
  return at;
}

export function dynamicAt(score: Score, at: EditPosition): Dynamic | null {
  return DYNAMICS[beatOf(score, at).dynamics - DynamicValue.PPP] ?? null;
}

const TUPLETS: Record<Tuplet, [number, number]> = { 1: [-1, -1], 3: [3, 2], 5: [5, 4], 6: [6, 4] };

export function setTuplet(score: Score, at: EditPosition, tuplet: Tuplet, settings = defaultSettings): EditPosition {
  const beat = beatOf(score, at);
  [beat.tupletNumerator, beat.tupletDenominator] = TUPLETS[tuplet];
  score.finish(settings);
  return at;
}

export function tupletAt(score: Score, at: EditPosition): Tuplet {
  const beat = beatOf(score, at);
  const match = ([3, 5, 6] as const).find((t) => {
    const [numerator, denominator] = TUPLETS[t];
    return beat.tupletNumerator === numerator && beat.tupletDenominator === denominator;
  });
  return match ?? 1;
}

/** An eighth before the cursor's beat, on the cursor's string; the cursor moves onto it. */
export function addGrace(score: Score, at: EditPosition, settings = defaultSettings): EditPosition {
  const ids = idSource(score);
  const target = beatOf(score, at);
  const grace = new alphaTab.model.Beat();
  grace.id = ids.beat();
  grace.graceType = GraceType.BeforeBeat;
  grace.duration = Duration.Eighth;
  grace.dynamics = target.dynamics;
  const note = new alphaTab.model.Note();
  note.id = ids.note();
  note.string = at.string;
  note.fret = noteAt(target, at.string)?.fret ?? 0;
  grace.addNote(note);
  const voice = voiceOf(score, at);
  grace.voice = voice;
  voice.beats.splice(at.beat, 0, grace);
  score.finish(settings);
  return at;
}
