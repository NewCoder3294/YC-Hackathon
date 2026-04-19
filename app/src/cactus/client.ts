import {
  CactusLM,
  type CactusLMMessage,
  type CactusLMTool,
  type CactusLMCompleteResult,
} from 'cactus-react-native';

// SDK registry keys are derived from HuggingFace weight filenames, not the
// org-prefixed model id. For Cactus-Compute/gemma-4-E2B-it, the registry key
// is 'gemma-4-e2b-it'. Pass that here, not 'google/gemma-4-E2B-it'.
export const DEFAULT_MODEL = 'gemma-4-e2b-it';

export type FunctionCall = NonNullable<CactusLMCompleteResult['functionCalls']>[number];

export type CompleteInput = {
  messages: CactusLMMessage[];
  tools?: CactusLMTool[];
  audio?: number[];
  maxTokens?: number;
  temperature?: number;
  signal?: AbortSignal;
};

export type CompleteResult = {
  response: string;
  functionCalls: FunctionCall[];
  totalTimeMs: number;
};

export class CactusClient {
  private lm: CactusLM | null = null;
  private loading: Promise<void> | null = null;
  private modelId: string | null = null;
  private downloaded = false;

  async ensureLoaded(
    modelId: string = DEFAULT_MODEL,
    onDownloadProgress?: (p: number) => void,
  ): Promise<void> {
    if (this.lm && this.modelId === modelId) return;
    if (this.loading) return this.loading;

    this.loading = (async () => {
      const lm = new CactusLM({
        model: modelId,
        options: { quantization: 'int4', pro: false },
      });
      if (!this.downloaded) {
        await lm.download({ onProgress: onDownloadProgress });
        this.downloaded = true;
      }
      this.lm = lm;
      this.modelId = modelId;
      this.loading = null;
    })();
    return this.loading;
  }

  async complete(input: CompleteInput): Promise<CompleteResult> {
    if (!this.lm) throw new Error('Cactus model not loaded — call ensureLoaded() first');
    if (input.signal?.aborted) throw new Error('Cactus.complete aborted before dispatch');

    const completePromise = this.lm.complete({
      messages: input.messages,
      tools: input.tools,
      audio: input.audio,
      options: {
        maxTokens: input.maxTokens ?? 512,
        temperature: input.temperature ?? 0.2,
      },
    });

    const result = await withAbort(completePromise, input.signal);
    return {
      response: result.response,
      functionCalls: result.functionCalls ?? [],
      totalTimeMs: result.totalTimeMs,
    };
  }

  async destroy(): Promise<void> {
    if (!this.lm) return;
    await this.lm.destroy();
    this.lm = null;
    this.modelId = null;
  }
}

function withAbort<T>(p: Promise<T>, signal?: AbortSignal): Promise<T> {
  if (!signal) return p;
  return new Promise<T>((resolve, reject) => {
    const onAbort = () => reject(new Error('Cactus.complete aborted'));
    signal.addEventListener('abort', onAbort, { once: true });
    p.then(
      (v) => { signal.removeEventListener('abort', onAbort); resolve(v); },
      (e) => { signal.removeEventListener('abort', onAbort); reject(e); },
    );
  });
}
