import * as alphaTab from '@coderline/alphatab';

import { Mixer } from './mixer';
import type {
  EngineEvent,
  PathPayload,
  PlayerOptionsPayload,
  RenderTrackPayload,
  Reply,
  Request,
  RangePayload,
  SeekBarPayload,
  SetLoopingPayload,
  SetStavesPayload,
  SetSpeedPayload,
  SetTracksPayload,
} from './protocol';
import { type HighlightApi, keepRangeHighlighted } from './range_highlight';
import { setStaves, showNotationAndTab } from './staves';
import { describeOpened, summarize } from './summary';
import { barAtTick } from './timeline';
import { LongPressSelection } from './touch_selection';

declare global {
  interface Window {
    duotab: { handle(json: string): void };
    /** Injected by webview_flutter's JavaScriptChannel. */
    DuoTab?: { postMessage(message: string): void };
  }
}

const post = (message: Reply | EngineEvent) => window.DuoTab?.postMessage(JSON.stringify(message));

const pageUrl = (relative: string) => new URL(relative, location.href).href;

// The app's loopback server serves Documents next to the engine.
const songUrl = (path: string) => `/songs/${path.split('/').map(encodeURIComponent).join('/')}`;

const settings = new alphaTab.Settings();
settings.core.fontDirectory = pageUrl('./alphatab/font/');
settings.display.staveProfile = alphaTab.StaveProfile.ScoreTab;
settings.player.playerMode = alphaTab.PlayerMode.EnabledSynthesizer;
settings.player.soundFont = pageUrl('./alphatab/soundfont/sonivox.sf2');
settings.player.enableCursor = true;
settings.player.scrollElement = document.scrollingElement as HTMLElement;

const api = new alphaTab.AlphaTabApi(document.getElementById('score')!, settings);
api.renderFinished.on(() => post({ event: 'rendered', payload: {} }));
api.error.on((e) => post({ event: 'error', payload: { message: String(e?.message ?? e) } }));

let pendingOpen: { resolve: (score: alphaTab.model.Score) => void; reject: (e: unknown) => void } | null =
  null;
api.playerStateChanged.on((e) =>
  post({ event: 'playerState', payload: { playing: e.state === alphaTab.synth.PlayerState.Playing } }),
);

const mixer = new Mixer(api);

// Only the owner's own selections are reported: ranges the engine sets
// (opening a song, restoring a saved loop) are not choices to save.
const postRange = () => {
  const r = api.playbackRange;
  const range = r ? { startTick: r.startTick, endTick: r.endTick } : null;
  post({ event: 'rangeChanged', payload: { range } satisfies RangePayload });
};
// alphaTab's own tap and mouse selection set or clear the range before this fires.
api.beatMouseUp.on(postRange);
keepRangeHighlighted(api as unknown as HighlightApi);

const scoreElement = document.getElementById('score')!;
const touchSelection = new LongPressSelection<alphaTab.model.Beat>({
  beatAt(x, y) {
    const rect = scoreElement.getBoundingClientRect();
    return api.renderer.boundsLookup?.getBeatAtPos(x - rect.left, y - rect.top) ?? null;
  },
  // The same ticks alphaTab's own mouse selection uses.
  select(start, end) {
    const cache = api.tickCache;
    if (!cache) return;
    const range = new alphaTab.synth.PlaybackRange();
    range.startTick = cache.getMasterBarStart(start.voice.bar.masterBar) + start.playbackStart;
    range.endTick = cache.getMasterBarStart(end.voice.bar.masterBar) + end.playbackStart + end.playbackDuration - 50;
    api.playbackRange = range;
    api.tickPosition = range.startTick;
  },
  commit: postRange,
});
scoreElement.addEventListener('touchstart', (e) => touchSelection.touchStart(e), { passive: true });
scoreElement.addEventListener('touchmove', (e) => touchSelection.touchMove(e), { passive: false });
scoreElement.addEventListener('touchend', (e) => touchSelection.touchEnd(e), { passive: false });
scoreElement.addEventListener('touchcancel', (e) => touchSelection.touchEnd(e), { passive: false });

let postedBar = -1;
const postBar = (bar: number) => {
  postedBar = bar;
  post({ event: 'position', payload: { bar } });
};
api.playerPositionChanged.on((e) => {
  const lookups = api.tickCache?.masterBars;
  if (!lookups) return;
  const bar = barAtTick(lookups, e.currentTick);
  if (bar !== postedBar) postBar(bar);
});

let openCount = 0;

/**
 * Waits for the open song's player. Throws without a song, and when another
 * song opened while waiting, so a stale command never reaches the new song.
 */
async function whenSongReady(): Promise<void> {
  if (!api.score) throw new Error('no song open');
  const opened = openCount;
  await whenPlayerReady();
  if (opened !== openCount) throw new Error('another song opened');
}

function whenPlayerReady(): Promise<void> {
  if (api.isReadyForPlayback) return Promise.resolve();
  return new Promise((resolve) => {
    const off = api.playerReady.on(() => {
      off();
      resolve();
    });
  });
}

// Runs before alphaTab's first render of the song.
api.scoreLoaded.on((score) => {
  showNotationAndTab(score);
  pendingOpen?.resolve(score);
  pendingOpen = null;
});
api.error.on((e) => {
  pendingOpen?.reject(e);
  pendingOpen = null;
});

async function fetchBytes(path: string): Promise<Uint8Array> {
  const response = await fetch(songUrl(path));
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return new Uint8Array(await response.arrayBuffer());
}

const fileName = (path: string) => path.split('/').pop() ?? path;

async function run(request: Request): Promise<unknown> {
  switch (request.type) {
    case 'ping':
      return {};
    case 'summarize': {
      const { path } = request.payload as PathPayload;
      return summarize(await fetchBytes(path), fileName(path));
    }
    case 'open': {
      const { path } = request.payload as PathPayload;
      const bytes = await fetchBytes(path);
      const loaded = new Promise<alphaTab.model.Score>((resolve, reject) => {
        pendingOpen = { resolve, reject };
      });
      openCount++;
      api.load(bytes, []);
      const score = await loaded;
      // Only once the new song is in: a failed open leaves the old one as it was.
      postedBar = -1;
      mixer.newSong();
      api.playbackSpeed = 1;
      api.isLooping = false;
      api.playbackRange = null;
      return describeOpened(score, fileName(path));
    }
    case 'renderTrack': {
      const { index } = request.payload as RenderTrackPayload;
      const track = api.score?.tracks[index];
      if (!track) throw new Error(`no track ${index}`);
      api.renderTracks([track]);
      return {};
    }
    case 'play':
      await whenSongReady();
      api.play();
      return {};
    case 'pause':
      api.pause();
      return {};
    case 'stop':
      api.stop();
      return {};
    case 'seekBar': {
      const { bar } = request.payload as SeekBarPayload;
      await whenSongReady();
      const masterBar = api.score?.masterBars[bar];
      if (!masterBar || !api.tickCache) throw new Error(`no bar ${bar}`);
      api.tickPosition = api.tickCache.getMasterBarStart(masterBar);
      api.scrollToCursor();
      postBar(bar);
      return {};
    }
    case 'setTracks': {
      const { tracks } = request.payload as SetTracksPayload;
      await whenSongReady();
      await mixer.apply(tracks);
      return {};
    }
    case 'setPlayerOptions': {
      const { countIn, metronome } = request.payload as PlayerOptionsPayload;
      api.countInVolume = countIn ? 1 : 0;
      api.metronomeVolume = metronome ? 1 : 0;
      return {};
    }
    case 'setStaves': {
      if (!api.score) throw new Error('no song open');
      setStaves(api.score, (request.payload as SetStavesPayload).staves);
      api.render();
      return {};
    }
    case 'setSpeed':
      api.playbackSpeed = (request.payload as SetSpeedPayload).speed;
      return {};
    case 'setLooping':
      api.isLooping = (request.payload as SetLoopingPayload).looping;
      return {};
    case 'setRange': {
      const { range } = request.payload as RangePayload;
      if (range) {
        const playbackRange = new alphaTab.synth.PlaybackRange();
        playbackRange.startTick = range.startTick;
        playbackRange.endTick = range.endTick;
        api.playbackRange = playbackRange;
      } else {
        api.playbackRange = null;
      }
      return {};
    }
  }
}

window.duotab = {
  handle(json: string) {
    const request = JSON.parse(json) as Request;
    run(request).then(
      (payload) => post({ id: request.id, ok: true, payload }),
      (e) => post({ id: request.id, ok: false, error: String((e as Error)?.message ?? e) }),
    );
  },
};

post({ event: 'ready', payload: {} });
