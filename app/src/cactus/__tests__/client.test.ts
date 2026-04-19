const downloadMock = jest.fn().mockResolvedValue(undefined);
const completeMock = jest.fn().mockResolvedValue({
  success: true,
  response: 'hello',
  functionCalls: [],
  totalTimeMs: 12,
  timeToFirstTokenMs: 0,
  prefillTokens: 0,
  prefillTps: 0,
  decodeTokens: 0,
  decodeTps: 0,
  totalTokens: 0,
});
const destroyMock = jest.fn().mockResolvedValue(undefined);
const ctorSpy = jest.fn();

jest.mock('cactus-react-native', () => {
  class CactusLM {
    constructor(params: unknown) { ctorSpy(params); }
    download = downloadMock;
    complete = completeMock;
    destroy  = destroyMock;
  }
  return { CactusLM };
});

import { CactusClient, DEFAULT_MODEL } from '../client';

beforeEach(() => {
  ctorSpy.mockClear();
  downloadMock.mockClear();
  completeMock.mockClear();
});

describe('CactusClient', () => {
  it('loads the model once and reuses the instance across calls', async () => {
    const c = new CactusClient();
    await c.ensureLoaded(DEFAULT_MODEL);
    await c.ensureLoaded(DEFAULT_MODEL);
    expect(ctorSpy).toHaveBeenCalledTimes(1);
    expect(downloadMock).toHaveBeenCalledTimes(1);
  });

  it('complete returns response + functionCalls + totalTimeMs', async () => {
    const c = new CactusClient();
    await c.ensureLoaded(DEFAULT_MODEL);
    const out = await c.complete({ messages: [{ role: 'user', content: 'hi' }] });
    expect(out.response).toBe('hello');
    expect(Array.isArray(out.functionCalls)).toBe(true);
    expect(out.totalTimeMs).toBeGreaterThanOrEqual(0);
  });

  it('complete respects AbortSignal', async () => {
    const c = new CactusClient();
    await c.ensureLoaded(DEFAULT_MODEL);
    const ac = new AbortController();
    ac.abort();
    await expect(
      c.complete({ messages: [{ role: 'user', content: 'x' }], signal: ac.signal }),
    ).rejects.toThrow(/abort/i);
  });
});
