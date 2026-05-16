export async function runLoop(
  name: string,
  intervalMs: number,
  fn: (signal: AbortSignal) => Promise<void>,
): Promise<void> {
  const controller = new AbortController();

  process.on("SIGINT", () => controller.abort());
  process.on("SIGTERM", () => controller.abort());

  while (!controller.signal.aborted) {
    try {
      await fn(controller.signal);
    } catch (err: unknown) {
      if (controller.signal.aborted) break;
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`[${name}] Error: ${msg}`);
    }

    const jitter = intervalMs * 0.1 * (Math.random() * 2 - 1);
    const wait = Math.max(1000, intervalMs + jitter);

    await new Promise<void>((resolve) => {
      const timer = setTimeout(resolve, wait);
      controller.signal.addEventListener("abort", () => {
        clearTimeout(timer);
        resolve();
      });
    });
  }
}
