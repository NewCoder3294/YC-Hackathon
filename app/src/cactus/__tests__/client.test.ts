jest.mock('cactus-react-native', () => ({
  Cactus: {
    load: jest.fn().mockResolvedValue({ sessionId: 'mock' }),
    generate: jest.fn().mockResolvedValue('{"transcript":"hi","stat_opportunity":false}'),
    close: jest.fn().mockResolvedValue(undefined),
  },
}));

import { CactusClient } from '../client';

describe('CactusClient', () => {
  it('loads the model once and reuses the session', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    await c.ensureLoaded('google/functiongemma-270m-it');
    const mod = require('cactus-react-native');
    expect(mod.Cactus.load).toHaveBeenCalledTimes(1);
  });

  it('generate returns string output', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    const out = await c.generate({ prompt: 'x' });
    expect(typeof out).toBe('string');
  });

  it('generate respects AbortSignal', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    const ac = new AbortController();
    ac.abort();
    await expect(c.generate({ prompt: 'x', signal: ac.signal })).rejects.toThrow(/abort/i);
  });
});
