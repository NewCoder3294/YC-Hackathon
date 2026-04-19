import '@expo/metro-runtime';
import React, { useState } from 'react';
import {
  IBMPlexMono_400Regular,
  IBMPlexMono_600SemiBold,
  IBMPlexMono_700Bold,
  useFonts,
} from '@expo-google-fonts/ibm-plex-mono';
import { Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { FONT_MONO, tokens } from './src/theme/tokens';
import { AppSidebar, ScreenId } from './src/navigation/AppSidebar';
import { AgentScreen } from './src/screens/AgentScreen';
import { SpottingBoardScreen } from './src/screens/SpottingBoardScreen';
import { Feature2Screen } from './src/screens/Feature2Screen';

export default function App() {
  const [fontsLoaded] = useFonts({
    [FONT_MONO]: IBMPlexMono_400Regular,
    [`${FONT_MONO}-SemiBold`]: IBMPlexMono_600SemiBold,
    [`${FONT_MONO}-Bold`]: IBMPlexMono_700Bold,
  });

  const [screen, setScreen] = useState<ScreenId>('F1');

  if (!fontsLoaded) {
    return (
      <View style={{ flex: 1, backgroundColor: tokens.bgBase, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: tokens.textMuted, fontSize: 12 }}>Loading IBM Plex Mono…</Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, flexDirection: 'row', backgroundColor: tokens.bgBase }}>
      <StatusBar style="light" />
      <AppSidebar active={screen} onChange={setScreen} />
      <View style={{ flex: 1 }}>
        {screen === 'AGENT' && <AgentScreen />}
        {screen === 'F1'    && <SpottingBoardScreen />}
        {screen === 'F2'    && <Feature2Screen />}
      </View>
    </View>
  );
}
