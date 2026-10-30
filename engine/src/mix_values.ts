// Guitar Pro 8 stores mixer levels as 0–1 fractions; these laws were measured
// from a file saved in Guitar Pro at known settings. A null dB is −∞.

export const trackDbFromStored = (stored: number): number => 50 * stored - 40;

export const storedFromTrackDb = (db: number | null): number => (db === null ? 0 : Math.min(1, Math.max(0, (db + 40) / 50)));

export const masterDbFromStored = (stored: number): number => 40 * (stored - 0.76);

export const panFromStored = (stored: number): number => 2 * stored - 1;

export const storedFromPan = (pan: number): number => (pan + 1) / 2;

/** A 0–16 volume as alphaTab plays it: the synth cubes MIDI volume, and 12 is the 0 dB reference. */
export const dbFromVolume = (volume: number): number | null => (volume <= 0 ? null : 60 * Math.log10(volume / 12));
