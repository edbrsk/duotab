import * as alphaTab from '@coderline/alphatab';

import type { EngineEvent, PathPayload, RenderTrackPayload, Reply, Request } from './protocol';
import { summarize, summarizeScore } from './summary';

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
api.scoreLoaded.on((score) => {
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
      // An empty track list keeps alphaTab from drawing before a track is chosen.
      api.load(bytes, []);
      return summarizeScore(await loaded, fileName(path));
    }
    case 'renderTrack': {
      const { index } = request.payload as RenderTrackPayload;
      const track = api.score?.tracks[index];
      if (!track) throw new Error(`no track ${index}`);
      api.renderTracks([track]);
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
