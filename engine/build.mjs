import { cpSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { build } from 'esbuild';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'assets', 'engine');
const dist = join(here, 'node_modules', '@coderline', 'alphatab', 'dist');

rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'alphatab'), { recursive: true });

await build({
  entryPoints: [join(here, 'src', 'main.ts')],
  outfile: join(out, 'engine.js'),
  bundle: true,
  format: 'esm',
  target: 'es2022',
  // Loaded through the page's import map, so alphaTab finds its worker and worklet next to itself.
  external: ['@coderline/alphatab'],
});

// The synth worker runs DuoScore's entry, which imports alphaTab's core as alphaTab's own
// entry does: module workers don't see the page's import map.
await build({
  entryPoints: [join(here, 'src', 'worker', 'entry.ts')],
  outfile: join(out, 'alphatab', 'alphaTab.worker.mjs'),
  bundle: true,
  format: 'esm',
  target: 'es2022',
  plugins: [
    {
      name: 'alphatab-core',
      setup(b) {
        b.onResolve({ filter: /^@coderline\/alphatab$/ }, () => ({ path: './alphaTab.core.mjs', external: true }));
      },
    },
  ],
});

cpSync(join(here, 'index.html'), join(out, 'index.html'));
for (const name of ['alphaTab.mjs', 'alphaTab.core.mjs', 'alphaTab.worklet.mjs', 'font']) {
  cpSync(join(dist, name), join(out, 'alphatab', name), { recursive: true });
}
cpSync(join(here, 'node_modules', '@coderline', 'alphatab', 'LICENSE'), join(out, 'alphatab', 'LICENSE'));
cpSync(join(here, 'soundfont'), join(out, 'soundfont'), { recursive: true });
