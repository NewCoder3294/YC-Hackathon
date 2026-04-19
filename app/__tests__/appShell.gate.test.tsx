import React from 'react';
import { render } from '@testing-library/react-native';

jest.mock('react-native-gesture-handler', () => ({
  GestureHandlerRootView: ({ children }: { children: React.ReactNode }) => children,
}));
jest.mock('expo-status-bar', () => ({ StatusBar: () => null }));
jest.mock('@expo/metro-runtime', () => ({}));
jest.mock('@expo-google-fonts/ibm-plex-mono', () => ({
  IBMPlexMono_400Regular: 'font',
  IBMPlexMono_600SemiBold: 'font',
  IBMPlexMono_700Bold: 'font',
  useFonts: () => [true],
}));
jest.mock('../src/cactus/state/matchCache', () => ({ loadMatchCache: () => {} }));
jest.mock('../assets/match_cache.json', () => ({}), { virtual: true });

jest.mock('../src/agent/AgentContext', () => ({
  AgentProvider: ({ children }: { children: React.ReactNode }) => children,
  useAgent: () => ({ active: false, pipVisible: false, showPiP: () => {} }),
}));
jest.mock('../src/ui/BackgroundPattern', () => ({
  PatternProvider: ({ children }: { children: React.ReactNode }) => children,
}));
jest.mock('../src/screens/AgentScreen', () => ({ AgentScreen: () => null }));
jest.mock('../src/screens/SpottingBoardScreen', () => ({ SpottingBoardScreen: () => null }));
jest.mock('../src/screens/Feature2Screen', () => ({ Feature2Screen: () => null }));
jest.mock('../src/screens/ArchiveScreen', () => ({ ArchiveScreen: () => null }));
jest.mock('../src/screens/TacticsScreen', () => ({ TacticsScreen: () => null }));
jest.mock('../src/navigation/AppSidebar', () => ({ AppSidebar: () => null }));
jest.mock('../src/agent/AgentPiP', () => ({ AgentPiP: () => null }));
jest.mock('../src/cactus/devtools/ModelPill', () => ({ ModelPill: () => null }));
jest.mock('../src/cactus/devtools/DevToolsOverlay', () => ({ DevToolsOverlay: () => null }));

type MockState = {
  status: 'unloaded' | 'downloading' | 'loading' | 'ready' | 'error';
  progress: number;
  error: string | null;
  ensureLoaded: jest.Mock;
  reset: jest.Mock;
};
const state: MockState = {
  status: 'downloading',
  progress: 0.1,
  error: null,
  ensureLoaded: jest.fn().mockResolvedValue(true),
  reset: jest.fn(),
};
jest.mock('../src/cactus/state/modelLoader', () => ({
  useModelLoader: (sel: (s: MockState) => unknown) => sel(state),
}));

import App from '../App';

describe('App — model gate', () => {
  it('renders the install screen while model is not ready', () => {
    const { getByText } = render(<App />);
    expect(getByText(/GEMMA 4 INSTALL/)).toBeTruthy();
  });
});
