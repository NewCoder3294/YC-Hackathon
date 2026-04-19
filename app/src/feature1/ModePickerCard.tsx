import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Circle, Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { MODE_OPTIONS } from '../fixtures/players';
import { Mode, ModeOptionSpec } from '../types';

type Props = {
  onPick?: (mode: Mode) => void;
  onSkip?: () => void;
};

export function ModePickerCard({ onPick, onSkip }: Props = {}) {
  return (
    <View
      style={{
        width: 480,
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 10,
        paddingVertical: 18,
        paddingHorizontal: 22,
        boxShadow: tokens.shadowCard,
      }}
    >
      {/* Header */}
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 10 }}>
        <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
          <Path d="M3 7l3 3 5-6"  stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M3 13l3 3 5-6" stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M3 19l3 3 5-6" stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" />
          <Path d="M14 8h7"       stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" />
          <Path d="M14 14h7"      stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" />
          <Path d="M14 20h7"      stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" />
        </Svg>
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.verified, fontWeight: '700' }}>
            READY · PRE-INDEXED OVERNIGHT
          </Text>
          <Text
            style={{ fontFamily: FONT_MONO, fontSize: 18, fontWeight: '700', color: tokens.text, marginTop: 4, letterSpacing: -0.18 }}
          >
            Pick your commentator style.
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 6, lineHeight: 17 }}>
            0 minutes of your prep.{' '}
            <Text style={{ color: tokens.text, fontWeight: '600' }}>46 players</Text> ·{' '}
            <Text style={{ color: tokens.text, fontWeight: '600' }}>184 storylines</Text> ·{' '}
            <Text style={{ color: tokens.text, fontWeight: '600' }}>23 precedent patterns</Text> pre-indexed.
          </Text>
        </View>
      </View>

      {/* Mode options */}
      <View style={{ marginTop: 18, gap: 8 }}>
        {MODE_OPTIONS.map((m) => (
          <Pressable key={m.id} onPress={() => onPick?.(m.id)}>
            <ModeOption mode={m} />
          </Pressable>
        ))}
      </View>

      {/* Footer */}
      <View style={{ marginTop: 14, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.4 }}>
          MODE IS A PREFERENCE — NOT A CAGE.
        </Text>
        <Pressable onPress={onSkip}>
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 10,
              color: tokens.textMuted,
              letterSpacing: 1.4,
              textDecorationLine: 'underline',
            }}
          >
            SKIP · CUSTOMIZE FROM SCRATCH
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

function ModeOption({ mode }: { mode: ModeOptionSpec }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 14,
        paddingVertical: 10,
        paddingHorizontal: 12,
        backgroundColor: tokens.bgSubtle,
        borderWidth: 1,
        borderColor: mode.recommended ? tokens.border : tokens.borderSoft,
        borderRadius: 6,
      }}
    >
      <ModeThumbnail mode={mode.id} />
      <View style={{ flex: 1 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', letterSpacing: 1.7, color: tokens.text }}>
            {mode.label}
          </Text>
          {mode.recommended && (
            <View
              style={{
                paddingVertical: 2,
                paddingHorizontal: 6,
                backgroundColor: 'rgba(16,185,129,0.1)',
                borderWidth: 1,
                borderColor: 'rgba(16,185,129,0.4)',
                borderRadius: 3,
              }}
            >
              <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.4, color: tokens.verified }}>
                RECOMMENDED FOR YOU
              </Text>
            </View>
          )}
        </View>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, marginTop: 3, lineHeight: 14 }}>
          {mode.sub}
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 9,
            color: tokens.textSubtle,
            marginTop: 5,
            fontStyle: 'italic',
            letterSpacing: 0.18,
          }}
        >
          {mode.hint}
        </Text>
      </View>
      <Svg viewBox="0 0 16 16" width={14} height={14} fill="none">
        <Path d="M5 3l5 5-5 5" stroke={tokens.textMuted} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" />
      </Svg>
    </View>
  );
}

function ModeThumbnail({ mode }: { mode: Mode }) {
  const wrap = {
    width: 110,
    height: 64,
    backgroundColor: tokens.bgRaised,
    borderWidth: 1,
    borderColor: tokens.borderSoft,
    borderRadius: 4,
    paddingVertical: 6,
    paddingHorizontal: 8,
  } as const;

  if (mode === 'STATS') {
    return (
      <View style={wrap}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 7, letterSpacing: 1, color: tokens.textSubtle }}>MESSI · xG</Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 18,
            fontWeight: '700',
            color: tokens.verified,
            lineHeight: 20,
            fontVariant: ['tabular-nums'] as any,
          }}
        >
          5.2
        </Text>
        <View style={{ flexDirection: 'row', gap: 6, marginTop: 4 }}>
          <View>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 6, color: tokens.textSubtle }}>xA</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text }}>3.1</Text>
          </View>
          <View>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 6, color: tokens.textSubtle }}>PROG</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text }}>47</Text>
          </View>
        </View>
      </View>
    );
  }

  if (mode === 'STORY') {
    return (
      <View style={wrap}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 7, letterSpacing: 1, color: tokens.textSubtle }}>MESSI · #10</Text>
        <Text
          style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '600', color: tokens.text, marginTop: 2, lineHeight: 12 }}
        >
          5th & final{'\n'}World Cup
        </Text>
        <View style={{ marginTop: 3, paddingLeft: 4, borderLeftWidth: 1, borderLeftColor: tokens.borderSoft }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 7, fontStyle: 'italic', color: tokens.textMuted }}>
            last dance · 35
          </Text>
        </View>
      </View>
    );
  }

  // TACTICAL
  return (
    <View style={wrap}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 7, letterSpacing: 1, color: tokens.textSubtle }}>
        MESSI · NO.10 FREE
      </Text>
      <Svg viewBox="0 0 80 32" width={92} height={36} style={{ marginTop: 2 }}>
        <Rect x={1} y={1} width={78} height={30} rx={1} fill="#0e1c12" stroke={tokens.border} strokeWidth={0.4} />
        <Circle cx={10} cy={16} r={1.3} fill={tokens.textMuted} />
        {[8, 16, 24].map((y) => (
          <Circle key={y} cx={22} cy={y * 0.9 + 4} r={1.3} fill={tokens.textMuted} />
        ))}
        <Circle cx={40} cy={12} r={1.3} fill={tokens.textMuted} />
        <Circle cx={40} cy={22} r={1.3} fill={tokens.textMuted} />
        <Circle cx={58} cy={10} r={1.8} fill={tokens.live} />
        <Circle cx={60} cy={16} r={1.3} fill={tokens.textMuted} />
        <Circle cx={58} cy={24} r={1.3} fill={tokens.textMuted} />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 7, color: tokens.esoteric, letterSpacing: 0.7, marginTop: 1 }}>
        3-3-2-2 FLEX
      </Text>
    </View>
  );
}
