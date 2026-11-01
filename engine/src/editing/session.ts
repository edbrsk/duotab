import * as alphaTab from '@coderline/alphatab';

import type { BarIssue, EditCommand, EditPosition, EditState, RetuneReport } from '../protocol';
import { describeOpened } from '../summary';
import { checkBars } from './bar_check';
import type { NoteMark } from './fingering';
import { type Clipboard, copyBars } from './bar_structure';
import { barProperties } from './bars';
import { runCommand, TRACK_OPS } from './commands';
import { structureAt } from './structure';
import { isGuitar, nearestGuitar } from './tracks';
import { History } from './history';
import { beatOf, clampPosition } from './position';
import { activeTechniques, bendAt, dynamicAt, tupletAt } from './techniques';
import { chordAt, fretsAt } from './chords';

type Score = alphaTab.model.Score;

const samePosition = (a: EditPosition, b: EditPosition) =>
  a.track === b.track && a.bar === b.bar && a.voice === b.voice && a.beat === b.beat && a.string === b.string;

/** The cursor, the bar check and the undo history of the open song's drawn track. */
export class EditSession {
  /** Null until the owner taps a string, so nothing edits a hidden position. */
  position: EditPosition | null = null;
  issues: BarIssue[] = [];
  track = 0;
  /** Notes the last retune, or fingering on open, moved or could not place, per track; until the next edit. */
  marks = new Map<number, NoteMark[]>();
  private report: RetuneReport | null = null;
  /** Where the last command set a fret and made an undo step, for a second digit to join. */
  private fretStep: EditPosition | null = null;
  readonly history: History;
  private name = '';
  /** Kept when another song opens, so bars can be copied between songs. */
  private clipboard: Clipboard | null = null;

  constructor(private readonly settings = new alphaTab.Settings()) {
    this.history = new History(100, settings);
  }

  /** `name` names an untitled song, as the library does. */
  open(score: Score, track: number, name = score.title, marks = new Map<number, NoteMark[]>()): void {
    this.name = name;
    this.fretStep = null;
    this.marks = marks;
    this.report = null;
    this.track = track;
    this.position = null;
    this.history.clear();
    this.issues = checkBars(score, track);
  }

  drawTrack(score: Score, track: number): void {
    this.track = track;
    this.position = null;
    this.issues = checkBars(score, track);
  }

  /** `selection`: the master-bar indexes the loop covers, if there is one. */
  command(score: Score, command: EditCommand, selection: { from: number; to: number } | null = null): { edited: boolean } {
    if (command.op === 'place') {
      this.position = clampPosition(score, { ...command.position, track: this.track });
      return { edited: false };
    }
    if (command.op === 'setTitle') {
      const at = this.position ?? { track: this.track, bar: 0, voice: 0, beat: 0, string: 1 };
      const { edited } = runCommand(score, at, command, this.history, this.settings);
      if (edited) this.clearMarks();
      return { edited };
    }
    if (TRACK_OPS.has(command.op)) return this.trackCommand(score, command);
    if (!this.position) throw new Error('no cursor');
    if (command.op === 'copyBars') {
      const { bar } = this.position;
      const [from, to] = selection && selection.from <= bar && bar <= selection.to ? [selection.from, selection.to] : [bar, bar];
      this.clipboard = copyBars(score, this.track, from, to);
      return { edited: false };
    }
    const joins =
      command.op === 'setFret' && command.combine === true && this.fretStep !== null && samePosition(this.fretStep, this.position);
    const sent = command.op === 'setFret' && !joins ? { ...command, combine: false } : command;
    const result = runCommand(score, this.position, sent, this.history, this.settings, this.clipboard);
    // Only a first digit that made its own step can be joined.
    this.fretStep = command.op === 'setFret' && result.edited && !joins ? { ...this.position } : null;
    this.position = result.position;
    if (result.edited) {
      this.issues = checkBars(score, this.track);
      this.clearMarks();
    }
    return { edited: result.edited };
  }

  /** An added track becomes drawn; otherwise the drawn track stays drawn, or the nearest guitar track when it goes. */
  private trackCommand(score: Score, command: EditCommand): { edited: boolean } {
    const drawn = score.tracks[this.track];
    const strings = drawn.staves[0].tuning.length;
    const at = this.position ?? { track: this.track, bar: 0, voice: 0, beat: 0, string: 1 };
    const { edited, marks } = runCommand(score, at, command, this.history, this.settings);
    if (!edited) return { edited };
    this.clearMarks();
    if (command.op === 'retune') {
      this.marks = new Map([[command.track, marks]]);
      const count = (kind: NoteMark['kind']) => marks.filter((m) => m.kind === kind).length;
      this.report = {
        track: command.track,
        tuning: [...command.tuning],
        octave: command.octave,
        keep: command.keep ?? 'pitch',
        moved: count('moved'),
        unplayable: count('unplayable'),
      };
    }
    const index = command.op === 'addTrack' ? -1 : score.tracks.indexOf(drawn);
    if (index >= 0) {
      this.track = index;
      if (this.position) {
        // A retune matches strings from the top, so the cursor stays on its string.
        const added = drawn.staves[0].tuning.length - strings;
        const string = command.op === 'retune' ? this.position.string + added : this.position.string;
        this.position = clampPosition(score, { ...this.position, track: index, string });
      }
    } else {
      this.track = command.op === 'addTrack' ? score.tracks.length - 1 : nearestGuitar(score, this.track);
      this.position = null;
    }
    this.issues = checkBars(score, this.track);
    return { edited };
  }

  /** After undo or redo replaced `previous` with `score`; the drawn track, found by its channel, stays drawn. */
  restored(score: Score, previous?: Score): void {
    this.clearMarks();
    this.fretStep = null;
    const channel = previous?.tracks[this.track]?.playbackInfo.primaryChannel;
    const same = score.tracks.findIndex((t) => t.playbackInfo.primaryChannel === channel);
    if (same >= 0 && isGuitar(score.tracks[same])) {
      this.track = same;
      if (this.position) this.position = { ...this.position, track: same };
    } else if (!score.tracks[this.track] || !isGuitar(score.tracks[this.track])) {
      this.track = nearestGuitar(score, Math.min(this.track, score.tracks.length - 1));
      this.position = null;
    }
    if (this.position) this.position = clampPosition(score, this.position);
    this.issues = checkBars(score, this.track);
  }

  state(score: Score, edited: boolean): EditState {
    const at = this.position;
    const beat = at ? beatOf(score, at) : null;
    return {
      position: this.position,
      issues: this.issues,
      canUndo: this.history.canUndo,
      canRedo: this.history.canRedo,
      song: describeOpened(score, this.name),
      edited,
      beat:
        at && beat
          ? {
              duration: beat.duration,
              dots: beat.dots,
              techniques: activeTechniques(score, at),
              dynamic: dynamicAt(score, at),
              tuplet: tupletAt(score, at),
              hasNote: beat.notes.some((n) => n.string === at.string),
              bend: bendAt(score, at),
              chord: chordAt(beat),
              frets: fretsAt(beat),
            }
          : null,
      bar: at ? barProperties(score, at) : null,
      structure: at ? structureAt(score, at) : null,
      canPaste: this.clipboard !== null,
      drawnTrack: this.track,
      retune: this.report,
    };
  }

  private clearMarks(): void {
    this.marks = new Map();
    this.report = null;
  }
}
