import React from 'react';
import { Text, View, ViewStyle } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

// iPadOS status bar — airplane-mode glyph on every screen (the demo's thesis).
function StatusBar({ minute = '9:41' }: { minute?: string }) {
  return (
    <View
      style={{
        height: 28,
        paddingHorizontal: 22,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        backgroundColor: 'transparent',
        zIndex: 2,
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 13, fontWeight: '600', color: tokens.text }}>{minute}</Text>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Svg width={16} height={16} viewBox="0 0 24 24">
          <Path
            d="M21 16v-2l-8-5V3.5a1.5 1.5 0 1 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"
            fill={tokens.text}
          />
        </Svg>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginRight: 2 }}>86%</Text>
          <View
            style={{
              width: 24,
              height: 11,
              borderRadius: 3,
              borderWidth: 1,
              borderColor: tokens.text,
              opacity: 0.9,
              padding: 1,
            }}
          >
            <View style={{ width: '80%', height: '100%', backgroundColor: tokens.text, borderRadius: 1 }} />
          </View>
          <View style={{ width: 2, height: 5, backgroundColor: tokens.text, borderRadius: 1, marginLeft: 1, opacity: 0.9 }} />
        </View>
      </View>
    </View>
  );
}

type Props = {
  children: React.ReactNode;
  bg?: string;
  style?: ViewStyle;
};

// Fills its container (flex: 1). On iPad that's 1366×1024 natively in landscape;
// on a laptop browser it's whatever the viewport is.
export function IPadFrame({ children, bg = tokens.bgBase, style }: Props) {
  return (
    <View
      style={[
        {
          flex: 1,
          backgroundColor: bg,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      {/* Ambient radial gradient — web-only, ignored on native */}
      <View
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: bg,
          ...({ backgroundImage: `radial-gradient(120% 80% at 50% -10%, #0c0c0c 0%, ${bg} 60%)` } as object),
        }}
      />
      <StatusBar />
      <View style={{ flex: 1, zIndex: 1 }}>{children}</View>
    </View>
  );
}
