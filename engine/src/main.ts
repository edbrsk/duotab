import * as alphaTab from '@coderline/alphatab';

import { Mixer } from './mixer';
import { movesTicks, TRACK_OPS } from './editing/commands';
import { hitTest } from './editing/hit_test';
import { drawAfterTrackEdit } from './editing/track_render';
import { newSong } from './editing/new_song';
import { drawOverlay } from './editing/overlay';
import { carryPlaybackSettings, rangeAfterTap } from './editing/restore';
import { EditSession } from './editing/session';
import { isGuitar } from './editing/tracks';
import type {
  EditPayload,
  EditState,
  EngineEvent,
  ExportPdfReply,
  NewSongOptions,
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
import { printPages } from './print_pages';

declare global {
  interface Window {
    duoscore: { handle(json: string): void };
    /** Injected by webview_flutter's JavaScriptChannel. */
    DuoScore?: { postMessage(message: string): void };
  }
}

const post = (message: Reply | EngineEvent) => window.DuoScore?.postMessage(JSON.stringify(message));

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
// Taps are resolved to strings from the layout, which only exists on the page
// when alphaTab renders here rather than in a worker.
settings.core.useWorkers = false;
// DuoScore handles taps itself: alphaTab's would clear the loop on every tap
// that places the edit cursor.
settings.player.enableUserInteraction = false;

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

const session = new EditSession(settings);

function redrawOverlay() {
  if (api.score) drawOverlay(scoreElement, api.renderer, api.score, session.position, session.issues);
}
api.postRenderFinished.on(redrawOverlay);

function editState(edited: boolean): EditState {
  redrawOverlay();
  return session.state(api.score!, edited);
}

scoreElement.addEventListener('click', (e) => {
  if (!api.score) return;
  const rect = scoreElement.getBoundingClientRect();
  const voice = session.position?.voice ?? 0;
  const hit = hitTest(api.renderer, session.track, voice, e.clientX - rect.left, e.clientY - rect.top);
  if (!hit) return;
  seekToBeat(hit);
  post({ event: 'tapped', payload: { position: { ...hit, string: hit.string ?? session.position?.string ?? 1 } } });
});

/** The master-bar indexes the loop covers, for copying the looped bars. */
function loopBars(): { from: number; to: number } | null {
  const range = api.playbackRange;
  const bars = api.tickCache?.masterBars;
  if (!range || !bars) return null;
  const at = (tick: number) => bars.find((b) => b.start <= tick && tick < b.end)?.masterBar.index;
  const from = at(range.startTick);
  const to = at(range.endTick);
  return from === undefined || to === undefined ? null : { from: Math.min(from, to), to: Math.max(from, to) };
}

/** Playback follows a tap, as in Guitar Pro; a loop survives a tap inside it. */
function seekToBeat(at: { bar: number; voice: number; beat: number }) {
  const cache = api.tickCache;
  const beat = api.score?.tracks[session.track].staves[0].bars[at.bar]?.voices[at.voice]?.beats[at.beat];
  if (!cache || !beat) return;
  const tick = cache.getMasterBarStart(beat.voice.bar.masterBar) + beat.playbackStart;
  const range = api.playbackRange;
  if (range && !rangeAfterTap(range, tick)) {
    api.playbackRange = null;
    postRange();
  }
  api.tickPosition = tick;
}

function base64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

/** Shows a new score object and waits until alphaTab has taken it in. */
function showScore(score: alphaTab.model.Score, tracks: number[]): Promise<alphaTab.model.Score> {
  const loaded = new Promise<alphaTab.model.Score>((resolve, reject) => {
    pendingOpen = { resolve, reject };
  });
  api.renderScore(score, tracks);
  return loaded;
}

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

// Set by `open`: only a file's own staff flags are replaced, before alphaTab's
// first render of it; a score restored by undo keeps the owner's choice.
let fromFile = false;
api.scoreLoaded.on((score) => {
  if (fromFile) showNotationAndTab(score);
  fromFile = false;
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

/** Once a new song is in: a failed open leaves the old one as it was. */
function startSong() {
  postedBar = -1;
  mixer.newSong();
  api.playbackSpeed = 1;
  api.isLooping = false;
  api.playbackRange = null;
}

async function restore(score: alphaTab.model.Score | null): Promise<EditState> {
  if (!score) return editState(false);
  carryPlaybackSettings(api.score!, score);
  // An undone track edit can leave the drawn index pointing elsewhere.
  session.restored(score, api.score!);
  const track = session.track;
  await mixer.regenerate(() => api.renderScore(score, [track]));
  return editState(true);
}

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
      fromFile = true;
      api.load(bytes, []);
      const score = await loaded;
      startSong();
      session.open(score, 0, fileName(path).replace(/\.[^.]+$/, ''));
      redrawOverlay();
      return describeOpened(score, fileName(path));
    }
    case 'renderTrack': {
      const { index } = request.payload as RenderTrackPayload;
      const track = api.score?.tracks[index];
      if (!track) throw new Error(`no track ${index}`);
      api.renderTracks([track]);
      session.drawTrack(api.score!, index);
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
    case 'edit': {
      if (!api.score) throw new Error('no song open');
      const { command } = request.payload as EditPayload;
      const result = session.command(api.score, command, loopBars());
      if (result.edited) {
        if (movesTicks(command) && api.playbackRange) {
          api.playbackRange = null;
          postRange();
        }
        if (TRACK_OPS.has(command.op)) {
          await drawAfterTrackEdit(api, mixer, session.track, command.op);
        } else {
          api.render();
          // The title is not in the MIDI.
          if (command.op !== 'setTitle') await mixer.regenerate();
        }
      }
      return editState(result.edited);
    }
    case 'undo':
      if (!api.score) throw new Error('no song open');
      return restore(await session.history.undo(api.score));
    case 'redo':
      if (!api.score) throw new Error('no song open');
      return restore(await session.history.redo(api.score));
    case 'newSong': {
      const options = request.payload as NewSongOptions;
      openCount++;
      const score = await showScore(newSong(options, settings), [0]);
      startSong();
      session.open(score, 0, options.title);
      redrawOverlay();
      return describeOpened(score, options.title);
    }
    case 'exportGp': {
      if (!api.score) throw new Error('no song open');
      return { base64: base64(new alphaTab.exporter.Gp7Exporter().export(api.score, settings)) };
    }
    case 'exportPdf': {
      if (!api.score) throw new Error('no song open');
      const track = api.score.tracks[session.track];
      if (!track || !isGuitar(track)) throw new Error('no guitar track');
      const fontUrl = pageUrl('./alphatab/font/Bravura.woff2');
      const pages = printPages(api.score, session.track, settings.display.staveProfile, fontUrl);
      return { pages, baseUrl: `${location.origin}/` } satisfies ExportPdfReply;
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

window.duoscore = {
  handle(json: string) {
    const request = JSON.parse(json) as Request;
    run(request).then(
      (payload) => post({ id: request.id, ok: true, payload }),
      (e) => post({ id: request.id, ok: false, error: String((e as Error)?.message ?? e) }),
    );
  },
};

post({ event: 'ready', payload: {} });
