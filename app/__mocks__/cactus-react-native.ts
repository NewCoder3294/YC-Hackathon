// Stub — keeps Jest from blowing up on the real native module.
// Tests that need real behaviour should use jest.mock('cactus-react-native', ...) inline.

export class CactusLM {
  constructor(_params?: unknown) {}
  async download(_params?: unknown): Promise<void> {}
  async complete(_params?: unknown): Promise<{
    success: boolean;
    response: string;
    functionCalls?: { name: string; arguments: Record<string, unknown> }[];
    totalTimeMs: number;
    timeToFirstTokenMs: number;
    prefillTokens: number;
    prefillTps: number;
    decodeTokens: number;
    decodeTps: number;
    totalTokens: number;
  }> {
    return {
      success: true,
      response: '{"transcript":"","stat_opportunity":false}',
      functionCalls: [],
      totalTimeMs: 0,
      timeToFirstTokenMs: 0,
      prefillTokens: 0,
      prefillTps: 0,
      decodeTokens: 0,
      decodeTps: 0,
      totalTokens: 0,
    };
  }
  async destroy(): Promise<void> {}
}

export const useCactusLM = () => new CactusLM();
