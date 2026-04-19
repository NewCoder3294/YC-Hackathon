import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { ListeningDot, LatencyTag, Waveform } from './atoms';

type Props = {
  clock: string;
  score: { arg: number; fra: number };
  phase: string;
  phaseColor?: string;
  listening: boolean;
  latency?: string;
  onVoicePress?: () => void;
  onVoiceRelease?: () => void;
  rightSlot?: React.ReactNode;
  children: React.ReactNode;
};

// The full right-pane shell: top bar (score · clock · phase · listening dot),
// body (where cards and panels stack), bottom bezel (press-to-talk + latency).
export function LivePaneShell({
  clock,
  score,
  phase,
  phaseColor,
  listening,
  latency = '842ms',
  onVoicePress,
  onVoiceRelease,
  rightSlot,
  children,
}: Props) {
  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      {/* Top bar */}
      <View
        style={{
          paddingVertical: 14,
          paddingHorizontal: 20,
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
          <View style={{ flexDirection: 'row', alignItems: 'baseline', gap: 8 }}>
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 22,
                fontWeight: '700',
                color: tokens.text,
                letterSpacing: -0.22,
                fontVariant: ['tabular-nums'] as any,
              }}
            >
              {score.arg}
            </Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2, color: tokens.textSubtle }}>ARG</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 14, color: tokens.textSubtle, marginHorizontal: 4 }}>·</Text>
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 22,
                fontWeight: '700',
                color: tokens.text,
                letterSpacing: -0.22,
                fontVariant: ['tabular-nums'] as any,
              }}
            >
              {score.fra}
            </Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2, color: tokens.textSubtle }}>FRA</Text>
          </View>
          <View
            style={{
              paddingVertical: 4,
              paddingHorizontal: 8,
              backgroundColor: tokens.bgSubtle,
              borderWidth: 1,
              borderColor: tokens.borderSoft,
              borderRadius: 3,
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 1.4, color: tokens.textMuted }}>{clock}</Text>
          </View>
          {phase && (
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: '700',
                color: phaseColor ?? tokens.textMuted,
              }}
            >
              {phase}
            </Text>
          )}
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <ListeningDot />
          {rightSlot}
        </View>
      </View>

      {/* Body */}
      <View style={{ flex: 1, paddingVertical: 14, paddingHorizontal: 20, gap: 14 }}>{children}</View>

      {/* Bottom bezel */}
      <View
        style={{
          borderTopWidth: 1,
          borderTopColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          paddingVertical: 14,
          paddingHorizontal: 20,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}
      >
        <Pressable
          onPressIn={onVoicePress}
          onPressOut={onVoiceRelease}
          style={{
            flex: 1,
            flexDirection: 'row',
            alignItems: 'center',
            gap: 10,
            paddingVertical: 12,
            paddingHorizontal: 16,
            backgroundColor: listening ? 'rgba(239,68,68,0.08)' : tokens.bgSubtle,
            borderWidth: 1,
            borderColor: listening ? tokens.live : tokens.border,
            borderRadius: 10,
          }}
        >
          <Svg viewBox="0 0 24 24" width={18} height={18} fill="none">
            <Rect x={9} y={2} width={6} height={12} rx={3} stroke={listening ? tokens.live : tokens.text} strokeWidth={1.75} />
            <Path
              d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8"
              stroke={listening ? tokens.live : tokens.text}
              strokeWidth={1.75}
              strokeLinecap="round"
            />
          </Svg>
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 11,
              fontWeight: '700',
              letterSpacing: 1.8,
              color: listening ? tokens.live : tokens.text,
            }}
          >
            {listening ? 'LISTENING…' : 'HOLD TO ASK'}
          </Text>
          {listening && <Waveform color={tokens.live} />}
        </Pressable>
        <LatencyTag ms={latency} />
      </View>
    </View>
  );
}
