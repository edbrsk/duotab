import * as alphaTab from '@coderline/alphatab';

type Score = alphaTab.model.Score;

/** Undo and redo by whole-song snapshots: a clone of a 150-bar song takes about 30 ms. */
export class History {
  private readonly undoStack: unknown[] = [];
  private readonly redoStack: unknown[] = [];

  constructor(
    private readonly limit = 100,
    private readonly settings = new alphaTab.Settings(),
  ) {}

  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  static snapshot(score: Score): unknown {
    return alphaTab.model.JsonConverter.scoreToJsObject(score);
  }

  /** The song as it is before an edit. */
  record(score: Score): void {
    this.push(History.snapshot(score));
  }

  /** A snapshot taken before a change that turned out to change the song. */
  push(snapshot: unknown): void {
    this.undoStack.push(snapshot);
    if (this.undoStack.length > this.limit) this.undoStack.shift();
    this.redoStack.length = 0;
  }

  undo(current: Score): Score | null {
    return this.step(this.undoStack, this.redoStack, current);
  }

  redo(current: Score): Score | null {
    return this.step(this.redoStack, this.undoStack, current);
  }

  clear(): void {
    this.undoStack.length = 0;
    this.redoStack.length = 0;
  }

  private step(from: unknown[], to: unknown[], current: Score): Score | null {
    const snapshot = from.pop();
    if (snapshot === undefined) return null;
    to.push(History.snapshot(current));
    return alphaTab.model.JsonConverter.jsObjectToScore(snapshot, this.settings);
  }
}
