import '@expo/metro-runtime';
import React from 'react';
import {
  IBMPlexMono_400Regular,
  IBMPlexMono_600SemiBold,
  IBMPlexMono_700Bold,
  useFonts,
} from '@expo-google-fonts/ibm-plex-mono';
import { Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { FONT_MONO, tokens } from './src/theme/tokens';
import { SpottingBoardScreen } from './src/screens/SpottingBoardScreen';

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
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      <StatusBar style="light" />
      <SpottingBoardScreen />
    </View>
  );
}
