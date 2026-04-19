import { create } from 'zustand';
import { CactusClient, DEFAULT_MODEL } from '../client';

export type ModelStatus = 'unloaded' | 'downloading' | 'loading' | 'ready' | 'error';

type State = {
  status: ModelStatus;
  progress: number;          // 0..1
  error: string | null;
  client: CactusClient;
  ensureLoaded: () => Promise<boolean>;
};

const sharedClient = new CactusClient();
let inflight: Promise<boolean> | null = null;

export const useModelLoader = create<State>((set, get) => ({
  status: 'unloaded',
  progress: 0,
  error: null,
  client: sharedClient,
  ensureLoaded: () => {
    if (get().status === 'ready') return Promise.resolve(true);
    if (inflight) return inflight;

    set({ status: 'downloading', progress: 0, error: null });
    inflight = (async () => {
      const MAX_ATTEMPTS = 5;
      let lastErr: unknown = null;
      for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
          await sharedClient.ensureLoaded(DEFAULT_MODEL, (p) => {
            set({ progress: p });
          });
          set({ status: 'ready', progress: 1 });
          inflight = null;
          return true;
        } catch (err) {
          lastErr = err;
          const msg = err instanceof Error ? err.message : String(err);
          // Retry on transient network errors. Cactus's downloadModel does NOT
          // currently resume; it re-downloads from scratch each retry, but at
          // least a flaky WiFi blip won't permanently brick the app.
          const transient = /network|connection|timed?\s*out|nsurl|cancel/i.test(msg);
          if (!transient || attempt === MAX_ATTEMPTS) {
            set({ status: 'error', error: `${msg} (attempt ${attempt}/${MAX_ATTEMPTS})` });
            inflight = null;
            return false;
          }
          // Exponential backoff: 2s, 4s, 8s, 16s.
          const delayMs = Math.min(2000 * 2 ** (attempt - 1), 16000);
          set({ status: 'downloading', progress: 0, error: `retrying in ${delayMs / 1000}s — ${msg.slice(0, 60)}` });
          await new Promise((r) => setTimeout(r, delayMs));
        }
      }
      const msg = lastErr instanceof Error ? lastErr.message : String(lastErr);
      set({ status: 'error', error: msg });
      inflight = null;
      return false;
    })();
    return inflight;
  },
}));
