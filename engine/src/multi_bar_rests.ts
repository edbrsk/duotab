type Stylesheet = { perTrackMultiBarRest: Set<number> | null };

let filesRests = false;

/**
 * The tracks a file draws with multi-bar rests. alphaTab asks it `has` both
 * when it lays out a track and when it writes a file; everything else lists
 * its contents.
 */
class DrawnRests extends Set<number> {
  override has(track: number): boolean {
    return filesRests && super.has(track);
  }
}

/**
 * Draws every bar on its own, so a bar inside a multi-bar rest can be tapped
 * and written in. The file keeps its own choice when it's saved.
 */
export function drawEveryBar(score: { stylesheet: Stylesheet }): void {
  const rests = score.stylesheet.perTrackMultiBarRest;
  if (rests && !(rests instanceof DrawnRests)) score.stylesheet.perTrackMultiBarRest = new DrawnRests(rests);
}

/** Runs `run` with the file's multi-bar rests in effect, as a file is written or printed. */
export function withFileRests<T>(run: () => T): T {
  filesRests = true;
  try {
    return run();
  } finally {
    filesRests = false;
  }
}
