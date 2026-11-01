import type { ChordAddition, ChordSpec, ChordType } from '../protocol';

const ROOTS = ['C', 'C♯', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B'];

/** Each type's tones above the root, and its "5th": the one a position may leave out. */
const TYPES: Record<ChordType, { tones: number[]; fifth: number | null; base: string }> = {
  maj: { tones: [0, 4, 7], fifth: 7, base: '' },
  m: { tones: [0, 3, 7], fifth: 7, base: 'm' },
  '7': { tones: [0, 4, 7, 10], fifth: 7, base: '7' },
  maj7: { tones: [0, 4, 7, 11], fifth: 7, base: 'maj7' },
  m7: { tones: [0, 3, 7, 10], fifth: 7, base: 'm7' },
  m7b5: { tones: [0, 3, 6, 10], fifth: 6, base: 'm7♭5' },
  dim7: { tones: [0, 3, 6, 9], fifth: 6, base: 'dim7' },
  aug: { tones: [0, 4, 8], fifth: 8, base: 'aug' },
  sus2: { tones: [0, 2, 7], fifth: 7, base: 'sus2' },
  sus4: { tones: [0, 5, 7], fifth: 7, base: 'sus4' },
  '6': { tones: [0, 4, 7, 9], fifth: 7, base: '6' },
  // Only the root and the 5th: neither may go.
  '5': { tones: [0, 7], fifth: null, base: '5' },
};

const ADDITIONS: Record<ChordAddition, { tone: number; label: string }> = {
  b9: { tone: 13, label: '♭9' },
  '9': { tone: 14, label: '9' },
  '#9': { tone: 15, label: '♯9' },
  '11': { tone: 17, label: '11' },
  '#11': { tone: 18, label: '♯11' },
  b13: { tone: 20, label: '♭13' },
  '13': { tone: 21, label: '13' },
};

const CLASHES: ChordAddition[][] = [
  ['b9', '9', '#9'],
  ['11', '#11'],
  ['b13', '13'],
];

/** Lowest first, as names list them. */
const ADDITION_ORDER: ChordAddition[] = ['b9', '9', '#9', '11', '#11', 'b13', '13'];

export function withAddition(additions: ChordAddition[], added: ChordAddition): ChordAddition[] {
  const group = CLASHES.find((g) => g.includes(added))!;
  return [...additions.filter((a) => !group.includes(a)), added];
}

/** Pitch classes. The bass of a slash chord isn't among them. */
export function chordTones(spec: ChordSpec): { required: number[]; optional: number[] } {
  const type = TYPES[spec.type];
  const pc = (interval: number) => (spec.root + interval) % 12;
  const required: number[] = [];
  const add = (p: number) => {
    if (!required.includes(p)) required.push(p);
  };
  for (const t of type.tones) if (t !== type.fifth) add(pc(t));
  for (const a of spec.additions) add(pc(ADDITIONS[a].tone));
  const optional = type.fifth === null || required.includes(pc(type.fifth)) ? [] : [pc(type.fifth)];
  return { required, optional };
}

export function chordName(spec: ChordSpec): string {
  const bass = spec.bass === null ? '' : `/${ROOTS[spec.bass]}`;
  return `${ROOTS[spec.root]}${suffix(spec.type, spec.additions)}${bass}`;
}

function suffix(type: ChordType, additions: ChordAddition[]): string {
  const has = (a: ChordAddition) => additions.includes(a);
  const left = ADDITION_ORDER.filter(has);
  const take = (a: ChordAddition) => left.splice(left.indexOf(a), 1);
  let name = TYPES[type].base;
  const items: string[] = [];

  if ((type === '7' || type === 'maj7' || type === 'm7') && has('9')) {
    // Extensions stack up from the 7th: the 9, then the 13 or the 11.
    const stem = type === '7' ? '' : type === 'maj7' ? 'maj' : 'm';
    take('9');
    let top = '9';
    if (has('13')) {
      take('13');
      top = '13';
    } else if (has('11')) {
      take('11');
      top = '11';
    }
    name = `${stem}${top}`;
  } else if (type === '6' && has('9')) {
    take('9');
    name = '6/9';
  } else if (type === 'maj' || type === 'm') {
    for (const natural of ['9', '11', '13'] as ChordAddition[]) {
      if (has(natural)) {
        take(natural);
        items.push(`add${natural}`);
      }
    }
  }
  items.push(...left.map((a) => ADDITIONS[a].label));
  if (items.length === 0) return name;
  if (type === 'maj' && items.length === 1 && items[0].startsWith('add')) return `${name}${items[0]}`;
  // A lone alteration only after a digit: "C♯11" would read as a C♯ chord.
  if (items.length === 1 && /[♭♯]/.test(items[0][0]) && /\d$/.test(name)) return `${name}${items[0]}`;
  const group = items.reduce((text, item) => (text && /^(\d|add)/.test(item) ? `${text},${item}` : `${text}${item}`), '');
  return `${name}(${group})`;
}

let suffixes: Map<string, { type: ChordType; additions: ChordAddition[] }> | null = null;

/** Every name DuoScore builds, by its part after the root. */
function suffixTable() {
  if (suffixes) return suffixes;
  suffixes = new Map();
  const choices = (group: ChordAddition[]) => [null, ...group];
  for (const type of Object.keys(TYPES) as ChordType[]) {
    for (const a of choices(CLASHES[0])) {
      for (const b of choices(CLASHES[1])) {
        for (const c of choices(CLASHES[2])) {
          const additions = [a, b, c].filter((x): x is ChordAddition => x !== null);
          const key = suffix(type, additions);
          if (suffixes.has(key)) throw new Error(`two chords named ${key}`);
          suffixes.set(key, { type, additions });
        }
      }
    }
  }
  return suffixes;
}

const NOTE = /^([A-G])([♯♭#b]?)/;

function pitchClass(letter: string, accidental: string): number {
  const natural = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[letter]!;
  const shift = accidental === '♯' || accidental === '#' ? 1 : accidental === '♭' || accidental === 'b' ? -1 : 0;
  return (natural + shift + 12) % 12;
}

/** Null for a name DuoScore can't build, such as "N.C.". */
export function parseChordName(name: string): ChordSpec | null {
  const root = NOTE.exec(name);
  if (!root) return null;
  let rest = name.slice(root[0].length);
  let bass: number | null = null;
  const slash = /\/([A-G])([♯♭#b]?)$/.exec(rest);
  if (slash) {
    bass = pitchClass(slash[1], slash[2]);
    rest = rest.slice(0, slash.index);
  }
  const normal = rest.replace(/#/g, '♯').replace(/b(?=\d)/g, '♭');
  const found = suffixTable().get(normal);
  if (!found) return null;
  return { root: pitchClass(root[1], root[2]), type: found.type, additions: [...found.additions], bass };
}
