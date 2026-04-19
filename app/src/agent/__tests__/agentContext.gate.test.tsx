import React from 'react';
import { renderHook, act } from '@testing-library/react-native';

type MockState = {
  status: 'ready' | 'downloading' | 'error' | 'unloaded' | 'loading';
  progress: number;
  error: string | null;
  ensureLoaded: jest.Mock;
  reset: jest.Mock;
};
const state: MockState = {
  status: 'downloading',
  progress: 0,
  error: null,
  ensureLoaded: jest.fn(),
  reset: jest.fn(),
};
jest.mock('../../cactus/state/modelLoader', () => ({
  useModelLoader: {
    getState: () => state,
    subscribe: () => () => {},
  },
}));
jest.mock('../../cactus/state/eventBus', () => ({
  useEventBus: {
    getState: () => ({ events: [] }),
    subscribe: () => () => {},
  },
}));

import { AgentProvider, useAgent } from '../AgentContext';

describe('AgentContext — model gate', () => {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <AgentProvider>{children}</AgentProvider>
  );

  beforeEach(() => {
    state.status = 'downloading';
  });

  it('start() is a no-op when model is not ready', () => {
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    expect(result.current.active).toBe(false);
  });

  it('start() activates once model is ready', () => {
    state.status = 'ready';
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    expect(result.current.active).toBe(true);
  });
});
