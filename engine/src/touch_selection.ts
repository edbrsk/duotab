export type TouchLike = {
  touches: ArrayLike<{ clientX: number; clientY: number }>;
  preventDefault(): void;
};

type Deps<B> = {
  beatAt(x: number, y: number): B | null;
  /** Shows the selection while the finger moves. */
  select(start: B, end: B): void;
  /** The finished selection, once the finger lifts. */
  commit?(start: B, end: B): void;
  /** False while the selection may only change when the finger lifts. */
  live?(): boolean;
  delayMs?: number;
  slopPx?: number;
};

/**
 * Long-press then drag selects beats on touch screens, where alphaTab only
 * selects with a mouse. A move before the delay is a scroll and selects nothing.
 */
export class LongPressSelection<B extends { absolutePlaybackStart: number }> {
  private readonly delayMs: number;
  private readonly slopPx: number;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private origin: { x: number; y: number } | null = null;
  private start: B | null = null;
  private current: B | null = null;

  constructor(private readonly deps: Deps<B>) {
    this.delayMs = deps.delayMs ?? 400;
    this.slopPx = deps.slopPx ?? 10;
  }

  touchStart(e: TouchLike): void {
    this.cancel();
    if (e.touches.length !== 1) return;
    const { clientX: x, clientY: y } = e.touches[0];
    this.origin = { x, y };
    this.timer = setTimeout(() => {
      this.timer = null;
      const beat = this.deps.beatAt(x, y);
      if (!beat) return this.cancel();
      this.start = beat;
      this.current = beat;
      if (this.deps.live?.() ?? true) this.emit();
    }, this.delayMs);
  }

  touchMove(e: TouchLike): void {
    const point = e.touches[0];
    if (!point) return;
    if (this.start) {
      e.preventDefault();
      const beat = this.deps.beatAt(point.clientX, point.clientY);
      if (beat && beat !== this.current) {
        this.current = beat;
        if (this.deps.live?.() ?? true) this.emit();
      }
      return;
    }
    if (this.origin && Math.hypot(point.clientX - this.origin.x, point.clientY - this.origin.y) > this.slopPx) {
      this.cancel();
    }
  }

  touchEnd(e: TouchLike): void {
    if (this.start) {
      // Keeps WebKit from sending the click that would clear alphaTab's range.
      e.preventDefault();
      this.emit();
      this.deps.commit?.(...this.ordered());
    }
    this.cancel();
  }

  private ordered(): [B, B] {
    const [a, b] = [this.start!, this.current!];
    return a.absolutePlaybackStart <= b.absolutePlaybackStart ? [a, b] : [b, a];
  }

  private emit(): void {
    this.deps.select(...this.ordered());
  }

  private cancel(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    this.origin = null;
    this.start = null;
    this.current = null;
  }
}
