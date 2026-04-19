import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { G, Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { Density } from '../types';

type Props = {
  mode?: string;              // display label like "STORY-FIRST"
  showModeChip?: boolean;
  savedStyle?: boolean;
  density?: Density;
  onModeChipPress?: () => void;
  onDensityChange?: (d: Density) => void;
};

export function BoardHeader({
  mode = 'STORY-FIRST',
  showModeChip = true,
  savedStyle = false,
  density = 'STANDARD',
  onModeChipPress,
  onDensityChange,
}: Props) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 14,
        paddingHorizontal: 20,
        borderBottomWidth: 1,
        borderBottomColor: tokens.borderSoft,
        backgroundColor: tokens.bgRaised,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
        {/* logo mark — matches frame.jsx */}
        <Svg viewBox="0 0 64 64" width={24} height={24}>
          <Rect width={64} height={64} rx={12} fill="#0A0A0A" />
          <Rect x={0.5} y={0.5} width={63} height={63} rx={11.5} stroke="#262626" fill="none" />
          <G transform="translate(16 16)">
            <Rect x={0}  y={0} width={3} height={32} fill="#FAFAFA" />
            <Rect x={7}  y={4} width={3} height={10} fill="#FAFAFA" />
            <Rect x={14} y={2} width={3} height={14} fill="#FAFAFA" />
            <Rect x={21} y={6} width={3} height={6}  fill="#EF4444" />
            <Rect x={28} y={3} width={3} height={12} fill="#FAFAFA" />
          </G>
        </Svg>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 2.2, color: tokens.text }}>
          BROADCASTBRAIN
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textSubtle, letterSpacing: 1.3 }}>· SPOTTING BOARD</Text>
        {showModeChip && (
          <Pressable onPress={onModeChipPress} hitSlop={4}>
            <ModeChip mode={mode} />
          </Pressable>
        )}
      </View>

      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        {savedStyle && <SavedStyleBadge />}
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.5 }}>DENSITY</Text>
        <DensitySlider value={density} onChange={onDensityChange} />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.5 }}>·</Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.5 }}>EXPORT PDF</Text>
      </View>
    </View>
  );
}

export function ModeChip({ mode }: { mode: string }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        paddingVertical: 5,
        paddingHorizontal: 10,
        borderRadius: 4,
        backgroundColor: tokens.bgSubtle,
        borderWidth: 1,
        borderColor: tokens.border,
      }}
    >
      <Svg width={10} height={10} viewBox="0 0 10 10">
        <Rect width={10} height={10} rx={5} fill={tokens.verified} />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.6, color: tokens.text }}>
        MODE · {mode}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>▾</Text>
    </View>
  );
}

export function SavedStyleBadge() {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 5,
        paddingVertical: 3,
        paddingHorizontal: 8,
        borderRadius: 3,
        backgroundColor: 'rgba(16,185,129,0.08)',
        borderWidth: 1,
        borderColor: 'rgba(16,185,129,0.4)',
      }}
    >
      <Svg viewBox="0 0 14 14" width={10} height={10} fill="none">
        <Path d="M3 7l3 3 5-6" stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.6, color: tokens.verified }}>
        MY STYLE · SAVED
      </Text>
    </View>
  );
}

type DensityProps = { value?: Density; onChange?: (d: Density) => void };

export function DensitySlider({ value = 'STANDARD', onChange }: DensityProps) {
  const options: Density[] = ['COMPACT', 'STANDARD', 'FULL'];
  return (
    <View
      style={{
        flexDirection: 'row',
        backgroundColor: tokens.bgSubtle,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 3,
        padding: 2,
      }}
    >
      {options.map((o) => {
        const active = o === value;
        return (
          <Pressable
            key={o}
            onPress={() => onChange?.(o)}
            style={{
              paddingVertical: 2,
              paddingHorizontal: 7,
              backgroundColor: active ? tokens.bgHover : 'transparent',
              borderRadius: 2,
            }}
          >
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 9,
                fontWeight: '700',
                letterSpacing: 1.3,
                color: active ? tokens.text : tokens.textSubtle,
              }}
            >
              {o}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
