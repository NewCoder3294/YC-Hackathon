import '@expo/metro-runtime';
import 'react-native-gesture-handler';
import React, { useState } from 'react';
import {
  IBMPlexMono_400Regular,
  IBMPlexMono_600SemiBold,
  IBMPlexMono_700Bold,
  useFonts,
} from '@expo-google-fonts/ibm-plex-mono';
import { Text, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { StatusBar } from 'expo-status-bar';
import { FONT_MONO, tokens } from './src/theme/tokens';
import { AppSidebar, ScreenId } from './src/navigation/AppSidebar';
import { AgentScreen } from './src/screens/AgentScreen';
import { SpottingBoardScreen } from './src/screens/SpottingBoardScreen';
import { Feature2Screen } from './src/screens/Feature2Screen';
import { ArchiveScreen } from './src/screens/ArchiveScreen';
import { PatternProvider } from './src/ui/BackgroundPattern';
import { AgentProvider, useAgent } from './src/agent/AgentContext';
import { AgentPiP } from './src/agent/AgentPiP';

export default function App() {
  const [fontsLoaded] = useFonts({
    [FONT_MONO]: IBMPlexMono_400Regular,
    [`${FONT_MONO}-SemiBold`]: IBMPlexMono_600SemiBold,
    [`${FONT_MONO}-Bold`]: IBMPlexMono_700Bold,
  });

  if (!fontsLoaded) {
    return (
      <View style={{ flex: 1, backgroundColor: tokens.bgBase, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: tokens.textMuted, fontSize: 12 }}>Loading IBM Plex Mono…</Text>
      </View>
    );
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <PatternProvider initial="dot-pulse">
        <AgentProvider>
          <AppShell />
        </AgentProvider>
      </PatternProvider>
    </GestureHandlerRootView>
  );
}

function AppShell() {
  const [screen, setScreen] = useState<ScreenId>('F1');
  const { active, pipVisible, showPiP } = useAgent();

  // Re-show the PiP every time the user visits Agent — so after a close,
  // returning to Agent + switching away pops it back.
  React.useEffect(() => {
    if (screen === 'AGENT') showPiP();
  }, [screen, showPiP]);

  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      <StatusBar style="light" />
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <AppSidebar active={screen} onChange={setScreen} agentLive={active} />
        <View style={{ flex: 1 }}>
          {screen === 'AGENT'   && <AgentScreen />}
          {screen === 'F1'      && <SpottingBoardScreen />}
          {screen === 'F2'      && <Feature2Screen />}
          {screen === 'ARCHIVE' && <ArchiveScreen />}
        </View>
      </View>

      {/* Floating agent window — listening agent + user elsewhere + window not manually closed */}
      {active && screen !== 'AGENT' && pipVisible && (
        <AgentPiP onExpand={() => setScreen('AGENT')} />
      )}
    </View>
  );
}
