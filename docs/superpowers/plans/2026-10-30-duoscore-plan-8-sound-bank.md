# DuoScore Plan 8: Sound Bank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play every song with GeneralUser GS, the bank the owner chose by ear, at about Sonivox's loudness and without clipping.

**Architecture:**
- **The bank** is committed under `engine/soundfont/` with its licence. The engine build copies it to `assets/engine/soundfont/`; the engine page loads it at startup. alphaTab's bundled `soundfont` folder (Sonivox) is no longer copied.
- **Level:** alphaTab's synth runs in a worker and posts each block of interleaved stereo samples to the page, which passes it to `api.player.output.addSamples`. The engine wraps that method with a limiter: a fixed gain of 2, then a stereo-linked peak limiter with instant attack, so no sample leaves above the ceiling.

**Tech Stack:** as Plan 7. alphaTab 1.6.1:
- `api.player.output` is the `ISynthOutput` (`AlphaSynthAudioWorkletOutput`), created in the `AlphaTabApi` constructor when `playerMode` is `EnabledSynthesizer`. It is replaced only when the player mode changes, which the app never does.
- `masterVolume` has no upper bound and no limiter behind it, so it is not used for the gain.

**Spec:** `docs/superpowers/specs/2026-10-29-duoscore-design.md`, Later phases › Sound bank: "the chosen bank replaces Sonivox and its licence joins the licence screen."

**Branch:** `plan-8-sound-bank`, from `main` (`30e4885`, tag `tone-fix`). The `spike/sound-banks` branch is never merged.

**Measurements** (offline render with alphaTab's `AlphaSynthAudioExporter` over the first 240 s; RMS / peak at gain 1):

| Song | Sonivox | GeneralUser GS | Difference |
|---|---|---|---|
| Collateral Damage | 0.066 / 0.478 | 0.032 / 0.258 | 6.4 dB |
| Headbutt | 0.036 / 0.385 | 0.009 / 0.115 | 11.7 dB |
| It Goes to Eleven | 0.077 / 0.641 | 0.035 / 0.353 | 6.7 dB |
| Mesh Head | 0.029 / 0.175 | 0.014 / 0.089 | 6.0 dB |
| Parade of Rage | 0.123 / **1.821** | 0.061 / 0.733 | 6.1 dB |
| Etude n°120 | 0.037 / 0.182 | 0.010 / 0.058 | 11.9 dB |

Gain 2 (+6 dB) matches the typical difference. Parade of Rage would peak at 1.47 with gain alone, which is what the limiter is for.

## Global Constraints

Plans 1–7's Global Constraints all apply. In addition:

- **Bank:** `GeneralUser-GS.sf2` v2.0.3, 32 319 396 bytes, SHA-256 `9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe`, from `https://github.com/mrbumpy409/GeneralUser-GS` (`GeneralUser-GS.sf2` at the repository root; licence at `documentation/LICENSE.txt`). The local copies are `/tmp/duoscore-banks/GeneralUser-GS.sf2` and `/tmp/duoscore-banks/generaluser-license/LICENSE.txt`.
- **Licence screen entry:** package name `GeneralUser GS`, text = `assets/engine/soundfont/LICENSE.txt`. It replaces the `Sonivox SoundFont` entry.
- **Level:** gain `2`, ceiling `0.95`, release `0.1` s (the time for the limiter's gain to recover most of the way to 1).

## Review Focus

- **Silence** (all-zero blocks, as between songs and after pause) stays exactly zero, with no `NaN` from a peak of 0.
- **One loud channel** turns both channels down by the same factor, so a hard-panned guitar doesn't shift the stereo image.
- **State across blocks:** a loud block followed by quiet ones recovers gradually, not with a jump at the block boundary.
- **The bank fails to load** (a build that missed the copy): the player reports it through the existing error path, the same as a missing Sonivox did.
- **Startup with a 32 MB bank:** the song still opens and plays; owner check on the simulator.

---

### Task 1: Bundle GeneralUser GS

**Files:**
- Create: `engine/soundfont/GeneralUser-GS.sf2`, `engine/soundfont/LICENSE.txt` (copied from the local copies above)
- Modify: `engine/build.mjs` (copy `engine/soundfont` to `assets/engine/soundfont`; drop `'soundfont'` from the alphaTab dist list)
- Modify: `engine/src/main.ts:62` (`pageUrl('./soundfont/GeneralUser-GS.sf2')`)
- Modify: `pubspec.yaml:63` (`assets/engine/soundfont/` replaces `assets/engine/alphatab/soundfont/`)
- Modify: `lib/features/settings/licences.dart`
- Modify: `docs/superpowers/specs/2026-10-29-duoscore-design.md` (Licences line 45 and Playback › SoundFont line 100 name GeneralUser GS; the Later phases › Sound bank entry goes)
- Test: `test/unit/features/settings/licences_test.dart`

- [ ] **Step 1: Write the failing test.** In `licences_test.dart`, the fake bundle serves `'assets/engine/soundfont/LICENSE.txt': 'GENERALUSER TEXT'` instead of the Sonivox path. The test is renamed `registers alphaTab, Bravura and GeneralUser GS`, and expects packages `['alphaTab', 'Bravura', 'GeneralUser GS']` and the last licence's text to contain `GENERALUSER TEXT`.

- [ ] **Step 2: Run it.** `flutter test test/unit/features/settings/licences_test.dart`. Expected: FAIL, because the fake bundle has no key `assets/engine/alphatab/soundfont/LICENSE` (null check).

- [ ] **Step 3: Implement.** Copy the bank and licence into `engine/soundfont/`, and make the `build.mjs`, `main.ts`, `pubspec.yaml` and `licences.dart` changes listed under Files.

- [ ] **Step 4: Verify.**
  - `flutter test test/unit/features/settings/licences_test.dart`. Expected: PASS.
  - `npm --prefix engine run build && ls assets/engine/soundfont assets/engine/alphatab && shasum -a 256 assets/engine/soundfont/GeneralUser-GS.sf2`. Expected: `GeneralUser-GS.sf2 LICENSE.txt`, no `soundfont` under `alphatab`, and the SHA-256 from the Global Constraints.
  - `grep -rn -i sonivox lib engine/src engine/build.mjs test pubspec.yaml`. Expected: no output.

- [ ] **Step 5: Update the spec** as listed under Files.

- [ ] **Step 6: Commit.**

```bash
git add engine/soundfont engine/build.mjs engine/src/main.ts pubspec.yaml lib/features/settings/licences.dart test/unit/features/settings/licences_test.dart docs/superpowers/specs/2026-10-29-duoscore-design.md
git commit -m "feat: play songs with GeneralUser GS"
```

### Task 2: Output level

**Files:**
- Create: `engine/src/output_level.ts`
- Modify: `engine/src/main.ts` (wrap the output right after `new alphaTab.AlphaTabApi`)
- Test: `engine/test/output_level.test.ts`

**Interfaces:**
- Produces:
  - `export class Limiter { constructor(sampleRate: number, gain = 2, ceiling = 0.95, releaseSeconds = 0.1); process(samples: Float32Array): void }` processes interleaved stereo in place. State (the current gain reduction) carries from one call to the next.
  - `export function limitOutput(output: { addSamples(samples: Float32Array): void }, limiter: Limiter): void` replaces `output.addSamples` with one that runs `limiter.process` and then the original.

- [ ] **Step 1: Write the failing tests** in `engine/test/output_level.test.ts`. Use sample rate 1000, so 0.1 s is 100 frames.
  - `a quiet block plays at twice its level`: `[0.1, -0.1, 0.2, -0.2]` → `[0.2, -0.2, 0.4, -0.4]` (`toBeCloseTo`, 6 digits).
  - `no sample leaves above the ceiling`: 200 frames of `0.8` → every `|sample| <= 0.95 + 1e-6` (the samples are float32).
  - `one loud channel turns both down alike`: a frame `[0.9, 0.1]` → `out[1] / out[0]` is `0.1 / 0.9` to 5 digits.
  - `the level recovers after a loud passage`: process 50 frames of `0.9`, then 1000 frames of `0.1` in a second call. The last output sample is `0.2` to 3 digits, and no output sample of the second call is lower than the one before it.
  - `silence stays silent`: 64 zeros → 64 zeros, none `NaN`.
  - `limitOutput limits every block the player sends`: a fake output records what its `addSamples` receives; after `limitOutput`, sending `[0.1, 0.1]` records `[0.2, 0.2]`.

- [ ] **Step 2: Run them.** `npm --prefix engine test -- output_level`. Expected: FAIL, cannot resolve `../src/output_level`.

- [ ] **Step 3: Implement `Limiter` and `limitOutput`.** Per frame:

```text
peak   = max(|L|, |R|) * gain
target = peak > ceiling ? ceiling / peak : 1
g      = target < g ? target : g + (target - g) * (1 - exp(-1 / (releaseSeconds * sampleRate)))
L, R   = L * gain * g, R * gain * g
```

`g` starts at 1.

- [ ] **Step 4: Run them.** `npm --prefix engine test -- output_level`. Expected: 6 passed.

- [ ] **Step 5: Wire it.** In `main.ts`, after the API is created: `limitOutput(api.player!.output, new Limiter(api.player!.output.sampleRate));`. Then run `npm --prefix engine run build && npx --prefix engine tsc --noEmit -p engine && npm --prefix engine test`. Expected: build succeeds, no type errors, all engine tests pass.

- [ ] **Step 6: Commit.**

```bash
git add engine/src/output_level.ts engine/src/main.ts engine/test/output_level.test.ts
git commit -m "feat(engine): raise the bank's level with a limiter so loud songs don't clip"
```

## Owner checks on the simulator

1. Collateral Damage plays with GeneralUser GS, about as loud as Sonivox was.
2. Clean, overdrive and high gain sound clearly different.
3. Parade of Rage plays its loudest passage without crackling.
4. Settings has no sound bank picker; Settings › Licences lists GeneralUser GS and not Sonivox.
5. Opening a song takes about as long as before.
