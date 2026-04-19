import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import { ModelInstallScreen } from '../ModelInstallScreen';

jest.mock('../../cactus/state/modelLoader', () => {
  const state = {
    status: 'downloading' as const,
    progress: 0.42,
    error: null as string | null,
    ensureLoaded: jest.fn().mockResolvedValue(true),
    reset: jest.fn(),
  };
  const useModelLoader = (sel: (s: typeof state) => unknown) => sel(state);
  return { useModelLoader, __state: state };
});

// eslint-disable-next-line @typescript-eslint/no-var-requires
const mod = require('../../cactus/state/modelLoader') as { __state: any };

describe('ModelInstallScreen', () => {
  beforeEach(() => {
    mod.__state.status = 'downloading';
    mod.__state.progress = 0.42;
    mod.__state.error = null;
    mod.__state.ensureLoaded.mockClear();
    mod.__state.reset.mockClear();
  });

  it('renders the progress percentage while downloading', () => {
    const { getByText } = render(<ModelInstallScreen />);
    expect(getByText(/42%/)).toBeTruthy();
  });

  it('shows the error message and a Retry button when status is error', () => {
    mod.__state.status = 'error';
    mod.__state.error = 'NSURLErrorDomain -1001';
    const { getByText } = render(<ModelInstallScreen />);
    expect(getByText(/NSURLErrorDomain/)).toBeTruthy();
    expect(getByText(/Retry/i)).toBeTruthy();
  });

  it('calls reset() then ensureLoaded() when Retry is pressed', () => {
    mod.__state.status = 'error';
    mod.__state.error = 'boom';
    const { getByText } = render(<ModelInstallScreen />);
    fireEvent.press(getByText(/Retry/i));
    expect(mod.__state.reset).toHaveBeenCalled();
    expect(mod.__state.ensureLoaded).toHaveBeenCalled();
  });
});
