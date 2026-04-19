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
      try {
        await sharedClient.ensureLoaded(DEFAULT_MODEL, (p) => {
          set({ progress: p });
        });
        set({ status: 'ready', progress: 1 });
        return true;
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        set({ status: 'error', error: msg });
        return false;
      } finally {
        inflight = null;
      }
    })();
    return inflight;
  },
}));
