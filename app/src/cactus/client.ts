// cactus-react-native is resolved at install-time in Task 0 + Task 7 spike.
// The surface below is the assumed shape. Adjust imports after the SDK spike.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const cactusMod: { Cactus: any } = require('cactus-react-native');
const { Cactus } = cactusMod;

export type GenerateInput = {
  prompt?: string;
  audio?: ArrayBuffer;
  tools?: unknown;
  signal?: AbortSignal;
};

export class CactusClient {
  private session: { sessionId: string } | null = null;
  private loading: Promise<void> | null = null;
  private modelId: string | null = null;

  async ensureLoaded(modelId: string): Promise<void> {
    if (this.session && this.modelId === modelId) return;
    if (this.loading) return this.loading;
    this.loading = (async () => {
      this.session = await Cactus.load({ model: modelId });
      this.modelId = modelId;
      this.loading = null;
    })();
    return this.loading;
  }

  async generate(input: GenerateInput): Promise<string> {
    if (!this.session) throw new Error('Cactus session not loaded');
    if (input.signal?.aborted) throw new Error('Cactus.generate aborted before dispatch');
    const genPromise = Cactus.generate({
      sessionId: this.session.sessionId,
      prompt: input.prompt,
      audio: input.audio,
      tools: input.tools,
    });
    return withAbort(genPromise, input.signal);
  }

  async close(): Promise<void> {
    if (!this.session) return;
    await Cactus.close({ sessionId: this.session.sessionId });
    this.session = null;
    this.modelId = null;
  }
}

function withAbort<T>(p: Promise<T>, signal?: AbortSignal): Promise<T> {
  if (!signal) return p;
  return new Promise<T>((resolve, reject) => {
    const onAbort = () => reject(new Error('Cactus.generate aborted'));
    signal.addEventListener('abort', onAbort, { once: true });
    p.then(
      (v) => { signal.removeEventListener('abort', onAbort); resolve(v); },
      (e) => { signal.removeEventListener('abort', onAbort); reject(e); },
    );
  });
}
