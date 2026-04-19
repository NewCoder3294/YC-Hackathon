import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { G, Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

export type ScreenId = 'AGENT' | 'F1' | 'F2';

type Status = 'DONE' | 'NEXT' | 'SOON';

type NavItem = {
  id: ScreenId;
  label: string;
  sub: string;
  status?: Status;
  icon: (color: string) => React.ReactNode;
};

// SVG paths pulled from stroke-style outline icons — keep simple, brand-consistent.
const icons = {
  agent: (c: string) => (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
      <Path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z" stroke={c} strokeWidth={1.6} strokeLinejoin="round" />
      <Path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" stroke={c} strokeWidth={1.6} strokeLinecap="round" />
    </Svg>
  ),
  board: (c: string) => (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
      <Rect x={3} y={4} width={7} height={16} rx={1.5} stroke={c} strokeWidth={1.6} />
      <Rect x={14} y={4} width={7} height={16} rx={1.5} stroke={c} strokeWidth={1.6} />
      <Path d="M5 9h3M5 13h3M16 9h3M16 13h3" stroke={c} strokeWidth={1.2} strokeLinecap="round" />
    </Svg>
  ),
  live: (c: string) => (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
      <Rect x={3} y={5} width={18} height={13} rx={2} stroke={c} strokeWidth={1.6} />
      <Path d="M8 21h8M12 18v3" stroke={c} strokeWidth={1.6} strokeLinecap="round" />
      <Path d="M8 11l2 2 3-4 4 5" stroke={c} strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" />
    </Svg>
  ),
  voice: (c: string) => (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
      <Path d="M4 12h2M8 8v8M12 5v14M16 8v8M20 12h-2" stroke={c} strokeWidth={1.6} strokeLinecap="round" />
    </Svg>
  ),
};

const NAV: NavItem[] = [
  { id: 'AGENT', label: 'AGENT',    sub: 'Home',            icon: icons.agent },
  { id: 'F1',    label: 'FEATURE 1', sub: 'Research Hub',    status: 'DONE', icon: icons.board },
  { id: 'F2',    label: 'FEATURE 2', sub: 'Live Dashboard',  status: 'DONE', icon: icons.live },
];

type Props = { active: ScreenId; onChange: (id: ScreenId) => void };

export function AppSidebar({ active, onChange }: Props) {
  return (
    <View
      style={{
        width: 92,
        backgroundColor: tokens.bgRaised,
        borderRightWidth: 1,
        borderRightColor: tokens.border,
        paddingVertical: 14,
      }}
    >
      {/* Logo */}
      <View style={{ alignItems: 'center', marginBottom: 18 }}>
        <Svg viewBox="0 0 64 64" width={34} height={34}>
          <Rect width={64} height={64} rx={12} fill={tokens.bgSubtle} />
          <Rect x={0.5} y={0.5} width={63} height={63} rx={11.5} stroke={tokens.border} fill="none" />
          <G transform="translate(16 16)">
            <Rect x={0}  y={0} width={3} height={32} fill="#FAFAFA" />
            <Rect x={7}  y={4} width={3} height={10} fill="#FAFAFA" />
            <Rect x={14} y={2} width={3} height={14} fill="#FAFAFA" />
            <Rect x={21} y={6} width={3} height={6}  fill="#EF4444" />
            <Rect x={28} y={3} width={3} height={12} fill="#FAFAFA" />
          </G>
        </Svg>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 8,
            fontWeight: '700',
            letterSpacing: 1.4,
            color: tokens.textSubtle,
            marginTop: 6,
          }}
        >
          BROADCAST{'\n'}BRAIN
        </Text>
      </View>

      {/* Nav items */}
      <View style={{ gap: 4 }}>
        {NAV.map((item) => (
          <NavButton
            key={item.id}
            item={item}
            active={active === item.id}
            onPress={() => onChange(item.id)}
          />
        ))}
      </View>

      {/* Bottom thesis indicator */}
      <View style={{ marginTop: 'auto', alignItems: 'center', paddingTop: 14 }}>
        <View
          style={{
            paddingVertical: 4,
            paddingHorizontal: 8,
            borderRadius: 3,
            backgroundColor: 'rgba(16,185,129,0.08)',
            borderWidth: 1,
            borderColor: 'rgba(16,185,129,0.3)',
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 7, fontWeight: '700', letterSpacing: 1.2, color: tokens.verified }}>
            AIRPLANE
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 7, fontWeight: '700', letterSpacing: 1.2, color: tokens.verified }}>
            MODE · ON
          </Text>
        </View>
      </View>
    </View>
  );
}

function NavButton({ item, active, onPress }: { item: NavItem; active: boolean; onPress: () => void }) {
  const disabled = item.status === 'SOON';
  const color = disabled ? tokens.textSubtle : active ? tokens.text : tokens.textMuted;

  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      style={({ hovered }: any) => ({
        position: 'relative',
        paddingVertical: 10,
        paddingHorizontal: 8,
        alignItems: 'center',
        backgroundColor: active ? tokens.bgSubtle : hovered && !disabled ? tokens.bgSubtle : 'transparent',
        opacity: disabled ? 0.5 : 1,
      })}
    >
      {active && (
        <View style={{ position: 'absolute', left: 0, top: 6, bottom: 6, width: 3, backgroundColor: tokens.live, borderRadius: 2 }} />
      )}
      {item.icon(color)}
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 8,
          fontWeight: '700',
          letterSpacing: 1.2,
          color,
          marginTop: 6,
          textAlign: 'center',
        }}
      >
        {item.label}
      </Text>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 8,
          color: disabled ? tokens.textSubtle : tokens.textSubtle,
          marginTop: 2,
          textAlign: 'center',
          letterSpacing: 0.2,
        }}
      >
        {item.sub}
      </Text>
      {item.status && (
        <View style={{ marginTop: 6 }}>
          <StatusChip status={item.status} />
        </View>
      )}
    </Pressable>
  );
}

function StatusChip({ status }: { status: Status }) {
  const palette: Record<Status, { bg: string; border: string; color: string; label: string }> = {
    DONE: { bg: 'rgba(16,185,129,0.1)',  border: 'rgba(16,185,129,0.4)', color: tokens.verified, label: 'DONE' },
    NEXT: { bg: 'rgba(245,158,11,0.1)',  border: 'rgba(245,158,11,0.4)', color: tokens.esoteric, label: 'NEXT' },
    SOON: { bg: tokens.bgSubtle,         border: tokens.borderSoft,       color: tokens.textSubtle, label: 'SOON' },
  };
  const p = palette[status];
  return (
    <View
      style={{
        paddingVertical: 1,
        paddingHorizontal: 5,
        borderRadius: 2,
        backgroundColor: p.bg,
        borderWidth: 1,
        borderColor: p.border,
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 7, fontWeight: '700', letterSpacing: 0.8, color: p.color }}>
        {p.label}
      </Text>
    </View>
  );
}
