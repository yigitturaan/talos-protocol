const COLORS: Record<string, string> = {
  honest: "\x1b[32m",
  yield: "\x1b[34m",
  liar: "\x1b[31m",
  manip: "\x1b[33m",
};
const RESET = "\x1b[0m";

export function createLogger(name: string) {
  const color = COLORS[name] || "";
  const prefix = `${color}[${name.toUpperCase()}]${RESET}`;

  return {
    info: (msg: string, data?: unknown) => {
      const ts = new Date().toISOString().slice(11, 19);
      const extra = data ? ` ${JSON.stringify(data)}` : "";
      console.log(`${ts} ${prefix} ${msg}${extra}`);
    },
    success: (msg: string, data?: unknown) => {
      const ts = new Date().toISOString().slice(11, 19);
      const extra = data ? ` ${JSON.stringify(data)}` : "";
      console.log(`${ts} ${prefix} \x1b[32m✓\x1b[0m ${msg}${extra}`);
    },
    error: (msg: string, data?: unknown) => {
      const ts = new Date().toISOString().slice(11, 19);
      const extra = data ? ` ${JSON.stringify(data)}` : "";
      console.error(`${ts} ${prefix} \x1b[31m✗\x1b[0m ${msg}${extra}`);
    },
    warn: (msg: string, data?: unknown) => {
      const ts = new Date().toISOString().slice(11, 19);
      const extra = data ? ` ${JSON.stringify(data)}` : "";
      console.log(`${ts} ${prefix} \x1b[33m⚠\x1b[0m ${msg}${extra}`);
    },
  };
}
