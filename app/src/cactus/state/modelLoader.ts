import { create } from 'zustand';
import { CactusClient, DEFAULT_MODEL } from '../client';

export type ModelStatus = 'unloaded' | 'downloading' | 'loading' | 'ready' | 'error';

type State = {
  status: ModelStatus;
  progress: number;          // 0..1
  error: string | null;
  client: CactusClient;
  ensureLoaded: () => Promise<boolean>;
  reset: () => void;
};

const sharedClient = new CactusClient();
let inflight: Promise<boolean> | null = null;
let currentToken: object = {};

export const useModelLoader = create<State>((set, get) => ({
  status: 'unloaded',
  progress: 0,
  error: null,
  client: sharedClient,
  ensureLoaded: () => {
    if (get().status === 'ready') return Promise.resolve(true);
    if (inflight) return inflight;

    const token = (currentToken = {});
    const guardedSet: typeof set = (...args) => {
      if (token !== currentToken) return;
      set(...(args as Parameters<typeof set>));
    };

    guardedSet({ status: 'downloading', progress: 0, error: null });
    inflight = (async () => {
      const MAX_ATTEMPTS = 5;
      let lastErr: unknown = null;
      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        if (token !== currentToken) return false;
        try {
          await sharedClient.ensureLoaded(DEFAULT_MODEL, (p) => {
            guardedSet({ progress: p });
          });
          guardedSet({ status: 'ready', progress: 1 });
          if (token === currentToken) inflight = null;
          return true;
        } catch (err) {
          lastErr = err;
          const msg = err instanceof Error ? err.message : String(err);
          // Retry on transient network errors. Cactus's downloadModel does NOT
          // currently resume; it re-downloads from scratch each retry, but at
          // least a flaky WiFi blip won't permanently brick the app.
          const transient = /network|connection|timed?\s*out|nsurl|cancel/i.test(msg);
          if (!transient || attempt === MAX_ATTEMPTS) {
            guardedSet({ status: 'error', error: `${msg} (attempt ${attempt}/${MAX_ATTEMPTS})` });
            if (token === currentToken) inflight = null;
            return false;
          }
          // Exponential backoff: 2s, 4s, 8s, 16s.
          const delayMs = Math.min(2000 * 2 ** (attempt - 1), 16000);
          guardedSet({ status: 'downloading', progress: 0, error: `retrying in ${delayMs / 1000}s — ${msg.slice(0, 60)}` });
          await new Promise((r) => setTimeout(r, delayMs));
        }
      }
      const msg = lastErr instanceof Error ? lastErr.message : String(lastErr);
      guardedSet({ status: 'error', error: msg });
      if (token === currentToken) inflight = null;
      return false;
    })();
    return inflight;
  },
  reset: () => {
    currentToken = {};
    inflight = null;
    set({ status: 'unloaded', progress: 0, error: null });
  },
}));
