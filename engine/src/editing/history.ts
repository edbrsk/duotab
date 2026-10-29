import * as alphaTab from '@coderline/alphatab';

type Score = alphaTab.model.Score;

async function compress(text: string): Promise<ArrayBuffer> {
  return new Response(new Blob([text]).stream().pipeThrough(new CompressionStream('gzip'))).arrayBuffer();
}

async function expand(bytes: ArrayBuffer): Promise<string> {
  return new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).text();
}

/**
 * Undo and redo by whole-song snapshots, kept gzipped: a 150-bar, 7-track
 * song is about 8 MB of JSON but 160 KB compressed.
 */
export class History {
  private readonly undoStack: Promise<ArrayBuffer>[] = [];
  private readonly redoStack: Promise<ArrayBuffer>[] = [];

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

  static snapshot(score: Score): string {
    return alphaTab.model.JsonConverter.scoreToJson(score);
  }

  /** The song as it is before an edit. */
  record(score: Score): void {
    this.push(History.snapshot(score));
  }

  /** A snapshot taken before a change that turned out to change the song. */
  push(snapshot: string): void {
    this.undoStack.push(compress(snapshot));
    if (this.undoStack.length > this.limit) this.undoStack.shift();
    this.redoStack.length = 0;
  }

  undo(current: Score): Promise<Score | null> {
    return this.step(this.undoStack, this.redoStack, current);
  }

  redo(current: Score): Promise<Score | null> {
    return this.step(this.redoStack, this.undoStack, current);
  }

  clear(): void {
    this.undoStack.length = 0;
    this.redoStack.length = 0;
  }

  /** What the history holds in memory. */
  async storedBytes(): Promise<number> {
    const all = await Promise.all([...this.undoStack, ...this.redoStack]);
    return all.reduce((total, bytes) => total + bytes.byteLength, 0);
  }

  private async step(from: Promise<ArrayBuffer>[], to: Promise<ArrayBuffer>[], current: Score): Promise<Score | null> {
    const snapshot = from.pop();
    if (snapshot === undefined) return null;
    to.push(compress(History.snapshot(current)));
    return alphaTab.model.JsonConverter.jsonToScore(await expand(await snapshot), this.settings);
  }
}
