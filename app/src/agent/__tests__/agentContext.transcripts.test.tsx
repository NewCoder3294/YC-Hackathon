import React from 'react';
import { renderHook, act } from '@testing-library/react-native';

type MockModelState = {
  status: 'ready' | 'downloading' | 'error' | 'unloaded' | 'loading';
  progress: number;
  error: string | null;
  ensureLoaded: jest.Mock;
  reset: jest.Mock;
};
const modelState: MockModelState = {
  status: 'ready',
  progress: 1,
  error: null,
  ensureLoaded: jest.fn(),
  reset: jest.fn(),
};
jest.mock('../../cactus/state/modelLoader', () => ({
  useModelLoader: {
    getState: () => modelState,
    subscribe: () => () => {},
  },
}));

// Minimal bus mock: subscribers get called whenever we set a new events array.
type Subscriber = (s: { events: unknown[] }) => void;
const subscribers: Subscriber[] = [];
let events: { type: string; text?: string; confidence?: number }[] = [];
jest.mock('../../cactus/state/eventBus', () => ({
  useEventBus: {
    getState: () => ({ events }),
    subscribe: (cb: Subscriber) => {
      subscribers.push(cb);
      return () => {
        const i = subscribers.indexOf(cb);
        if (i >= 0) subscribers.splice(i, 1);
      };
    },
  },
}));

function emit(event: { type: string; text?: string; confidence?: number }) {
  events = [...events, event];
  for (const cb of subscribers) cb({ events });
}

import { AgentProvider, useAgent } from '../AgentContext';

describe('AgentContext — live transcripts', () => {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <AgentProvider>{children}</AgentProvider>
  );

  beforeEach(() => {
    modelState.status = 'ready';
    events = [];
    subscribers.length = 0;
  });

  it('appends transcript events to the transcripts slice when agent is active', () => {
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    act(() => emit({ type: 'transcript', text: 'messi dribbling down the left', confidence: 0.9 }));
    expect(result.current.transcripts).toHaveLength(1);
    expect(result.current.transcripts[0].text).toBe('messi dribbling down the left');
  });

  it('keeps at most 5 transcripts (newest first)', () => {
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    for (let i = 0; i < 7; i++) {
      act(() => emit({ type: 'transcript', text: `line ${i}`, confidence: 0.9 }));
    }
    expect(result.current.transcripts).toHaveLength(5);
    expect(result.current.transcripts[0].text).toBe('line 6');
    expect(result.current.transcripts[4].text).toBe('line 2');
  });

  it('ignores non-transcript events', () => {
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    act(() => emit({ type: 'stat_card' }));
    expect(result.current.transcripts).toHaveLength(0);
  });

  it('clears transcripts on stop', () => {
    const { result } = renderHook(() => useAgent(), { wrapper });
    act(() => result.current.start());
    act(() => emit({ type: 'transcript', text: 'hello', confidence: 0.9 }));
    expect(result.current.transcripts).toHaveLength(1);
    act(() => result.current.stop());
    expect(result.current.transcripts).toHaveLength(0);
  });
});
