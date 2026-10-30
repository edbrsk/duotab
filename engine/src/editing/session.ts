import * as alphaTab from '@coderline/alphatab';

import type { BarIssue, EditCommand, EditPosition, EditState } from '../protocol';
import { describeOpened } from '../summary';
import { checkBars } from './bar_check';
import { type Clipboard, copyBars } from './bar_structure';
import { barProperties } from './bars';
import { runCommand } from './commands';
import { structureAt } from './structure';
import { History } from './history';
import { beatOf, clampPosition } from './position';
import { activeTechniques, bendAt, dynamicAt, tupletAt } from './techniques';

type Score = alphaTab.model.Score;

/** The cursor, the bar check and the undo history of the open song's drawn track. */
export class EditSession {
  /** Null until the owner taps a string, so nothing edits a hidden position. */
  position: EditPosition | null = null;
  issues: BarIssue[] = [];
  track = 0;
  readonly history: History;
  private name = '';
  /** Kept when another song opens, so bars can be copied between songs. */
  private clipboard: Clipboard | null = null;

  constructor(private readonly settings = new alphaTab.Settings()) {
    this.history = new History(100, settings);
  }

  /** `name` names an untitled song, as the library does. */
  open(score: Score, track: number, name = score.title): void {
    this.name = name;
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
      return { edited: runCommand(score, at, command, this.history, this.settings).edited };
    }
    if (!this.position) throw new Error('no cursor');
    if (command.op === 'copyBars') {
      const { bar } = this.position;
      const [from, to] = selection && selection.from <= bar && bar <= selection.to ? [selection.from, selection.to] : [bar, bar];
      this.clipboard = copyBars(score, this.track, from, to);
      return { edited: false };
    }
    const result = runCommand(score, this.position, command, this.history, this.settings, this.clipboard);
    this.position = result.position;
    if (result.edited) this.issues = checkBars(score, this.track);
    return { edited: result.edited };
  }

  /** After undo or redo replaced the score. */
  restored(score: Score): void {
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
            }
          : null,
      bar: at ? barProperties(score, at) : null,
      structure: at ? structureAt(score, at) : null,
      canPaste: this.clipboard !== null,
    };
  }
}
