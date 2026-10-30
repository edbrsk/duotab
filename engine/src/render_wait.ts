/** Resolves once `event` (alphaTab's postRenderFinished) next fires. */
export function nextRender(event: { on(handler: () => void): () => void }): Promise<void> {
  return new Promise((resolve) => {
    const off = event.on(() => {
      off();
      resolve();
    });
  });
}
