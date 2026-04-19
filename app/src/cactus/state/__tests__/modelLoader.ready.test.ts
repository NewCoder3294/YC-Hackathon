import { act } from '@testing-library/react-native';

jest.mock('../../client', () => {
  const ensureLoaded = jest.fn();
  return {
    DEFAULT_MODEL: 'gemma-4-e2b-it',
    CactusClient: jest.fn().mockImplementation(() => ({ ensureLoaded })),
    __mockEnsureLoaded: ensureLoaded,
  };
});

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { __mockEnsureLoaded } = require('../../client') as { __mockEnsureLoaded: jest.Mock };
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { useModelLoader } = require('../modelLoader') as typeof import('../modelLoader');

describe('modelLoader.reset', () => {
  beforeEach(() => {
    __mockEnsureLoaded.mockReset();
    useModelLoader.getState().reset();
  });

  it('clears error state and allows re-invocation', async () => {
    __mockEnsureLoaded.mockRejectedValueOnce(new Error('boom'));

    await act(async () => {
      const ok = await useModelLoader.getState().ensureLoaded();
      expect(ok).toBe(false);
    });
    expect(useModelLoader.getState().status).toBe('error');
    expect(useModelLoader.getState().error).toMatch(/boom/);

    act(() => { useModelLoader.getState().reset(); });
    expect(useModelLoader.getState().status).toBe('unloaded');
    expect(useModelLoader.getState().error).toBeNull();

    __mockEnsureLoaded.mockResolvedValueOnce(undefined);
    await act(async () => {
      const ok = await useModelLoader.getState().ensureLoaded();
      expect(ok).toBe(true);
    });
    expect(useModelLoader.getState().status).toBe('ready');
  });
});
