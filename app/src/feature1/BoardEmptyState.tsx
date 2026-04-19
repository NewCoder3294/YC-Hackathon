import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

type Props = { onBuild?: () => void };

export function BoardEmptyState({ onBuild }: Props) {
  return (
    <View
      style={{
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        padding: 40,
        gap: 20,
      }}
    >
      <Svg width={64} height={64} viewBox="0 0 64 64" fill="none">
        <Rect x={8} y={8} width={48} height={48} rx={4} stroke={tokens.textSubtle} strokeWidth={1.5} strokeDasharray="3 3" />
        <Path d="M24 32h16M32 24v16" stroke={tokens.textSubtle} strokeWidth={1.5} strokeLinecap="round" />
      </Svg>
      <View style={{ alignItems: 'center' }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.textSubtle, fontWeight: '700' }}>
          ARG vs FRA · WC FINAL
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 20,
            fontWeight: '700',
            color: tokens.text,
            marginTop: 6,
            letterSpacing: -0.2,
          }}
        >
          Tap to build your board.
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 11,
            color: tokens.textMuted,
            marginTop: 8,
            lineHeight: 17,
            maxWidth: 360,
            textAlign: 'center',
          }}
        >
          Overnight build complete: roster, stats, history, storylines, precedent patterns — all local, airplane-mode safe.
        </Text>
      </View>
      <Pressable
        onPress={onBuild}
        style={{ paddingVertical: 12, paddingHorizontal: 22, backgroundColor: tokens.live, borderRadius: 6 }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 2, color: '#fff' }}>
          BUILD BOARD →
        </Text>
      </Pressable>
      <View style={{ flexDirection: 'row', gap: 16, marginTop: 10 }}>
        {['46 PLAYERS', '·', '184 STORYLINES', '·', '23 PRECEDENTS'].map((s, i) => (
          <Text key={i} style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.4 }}>
            {s}
          </Text>
        ))}
      </View>
    </View>
  );
}
