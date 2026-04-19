import React from 'react';
import { Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';

type Props = {
  n: number;
  text: string;
  top?: number;
  left?: number;
  right?: number;
  bottom?: number;
};

export function Callout({ n, text, top, left, right, bottom }: Props) {
  return (
    <View
      style={{
        position: 'absolute',
        top,
        left,
        right,
        bottom,
        zIndex: 4,
        flexDirection: 'row',
        alignItems: 'flex-start',
        gap: 8,
        maxWidth: 220,
      }}
    >
      <View
        style={{
          width: 22,
          height: 22,
          borderRadius: 11,
          backgroundColor: tokens.esoteric,
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 4px 12px rgba(245,158,11,0.5)',
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', color: '#1a1100' }}>{n}</Text>
      </View>
      <View
        style={{
          backgroundColor: '#fffbea',
          borderWidth: 1,
          borderColor: 'rgba(245,158,11,0.4)',
          paddingVertical: 8,
          paddingHorizontal: 10,
          borderRadius: 4,
          boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: '#1a1614', lineHeight: 14, letterSpacing: 0.1 }}>{text}</Text>
      </View>
    </View>
  );
}
