import { expect, test } from 'vitest';

import { nextRender } from '../src/render_wait';

test('nextRender resolves on the next render, once', async () => {
  const handlers: (() => void)[] = [];
  const event = {
    on(handler: () => void) {
      handlers.push(handler);
      return () => handlers.splice(handlers.indexOf(handler), 1);
    },
  };
  let done = false;
  const drawn = nextRender(event).then(() => (done = true));
  await Promise.resolve();
  expect(done).toBe(false);
  [...handlers].forEach((h) => h());
  await drawn;
  expect(done).toBe(true);
  expect(handlers).toHaveLength(0);
});
