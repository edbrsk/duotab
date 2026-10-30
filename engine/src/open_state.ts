import type * as alphaTab from '@coderline/alphatab';

type Waiting = {
  resolve(score: alphaTab.model.Score): void;
  reject(e: unknown): void;
  fromFile: boolean;
};

/**
 * The song alphaTab is loading. alphaTab reports a load only by events, so
 * one open waits at a time: a newer open replaces it, and a failure ends it.
 */
export class OpenState {
  private waiting: Waiting | null = null;

  /** `fromFile`: the score comes from a file, which gets fingered and both staves. */
  wait(options: { fromFile: boolean }): Promise<alphaTab.model.Score> {
    this.waiting?.reject(new Error('another song opened'));
    return new Promise((resolve, reject) => {
      this.waiting = { resolve, reject, fromFile: options.fromFile };
    });
  }

  /** Whether the loaded score came from a file. */
  loaded(score: alphaTab.model.Score): boolean {
    const waiting = this.waiting;
    this.waiting = null;
    waiting?.resolve(score);
    return waiting?.fromFile ?? false;
  }

  failed(e: unknown): void {
    const waiting = this.waiting;
    this.waiting = null;
    waiting?.reject(e);
  }
}
