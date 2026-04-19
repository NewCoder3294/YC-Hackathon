import React, { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Circle, G, Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens, useTheme } from '../theme/tokens';

export type ScreenId = 'AGENT' | 'F1' | 'F2' | 'ARCHIVE';

type NavItem = {
  id: ScreenId;
  label: string;
  sub: string;
  icon: (color: string) => React.ReactNode;
};

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
  archive: (c: string) => (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
      <Rect x={3} y={5} width={18} height={4} rx={1} stroke={c} strokeWidth={1.6} />
      <Path d="M5 9v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9" stroke={c} strokeWidth={1.6} strokeLinejoin="round" />
      <Path d="M10 13h4" stroke={c} strokeWidth={1.6} strokeLinecap="round" />
    </Svg>
  ),
  chevron: (c: string, dir: 'left' | 'right') => (
    <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
      <Path
        d={dir === 'left' ? 'M15 6l-6 6 6 6' : 'M9 6l6 6-6 6'}
        stroke={c}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  ),
};

const NAV: NavItem[] = [
  { id: 'AGENT',   label: 'AGENT',    sub: 'Home',           icon: icons.agent },
  { id: 'F1',      label: 'RESEARCH', sub: 'Spotting Board', icon: icons.board },
  { id: 'F2',      label: 'LIVE',     sub: 'Match Dashboard',icon: icons.live },
  { id: 'ARCHIVE', label: 'ARCHIVE',  sub: 'Past Sessions',  icon: icons.archive },
];

type Props = { active: ScreenId; onChange: (id: ScreenId) => void; agentLive?: boolean };

const COLLAPSED_WIDTH = 64;
const EXPANDED_WIDTH = 208;

export function AppSidebar({ active, onChange, agentLive }: Props) {
  const [collapsed, setCollapsed] = useState(false);
  const mode = useTheme((s) => s.mode);
  const toggleTheme = useTheme((s) => s.toggle);
  const width = collapsed ? COLLAPSED_WIDTH : EXPANDED_WIDTH;

  return (
    <View
      style={{
        width,
        backgroundColor: tokens.bgRaised,
        borderRightWidth: 1,
        borderRightColor: tokens.border,
        paddingVertical: 14,
        // @ts-expect-error web transition
        transition: 'width 180ms ease',
      }}
    >
      {/* Header — logo + brand text when expanded, logo only when collapsed */}
      <View
        style={{
          flexDirection: collapsed ? 'column' : 'row',
          alignItems: 'center',
          gap: collapsed ? 0 : 10,
          paddingHorizontal: collapsed ? 0 : 14,
          justifyContent: collapsed ? 'center' : 'flex-start',
          marginBottom: 18,
        }}
      >
        <Svg viewBox="0 0 64 64" width={34} height={34}>
          <Rect width={64} height={64} rx={12} fill={tokens.bgSubtle} />
          <Rect x={0.5} y={0.5} width={63} height={63} rx={11.5} stroke={tokens.border} fill="none" />
          <G transform="translate(16 16)">
            <Rect x={0}  y={0} width={3} height={32} fill={tokens.text} />
            <Rect x={7}  y={4} width={3} height={10} fill={tokens.text} />
            <Rect x={14} y={2} width={3} height={14} fill={tokens.text} />
            <Rect x={21} y={6} width={3} height={6}  fill="#EF4444" />
            <Rect x={28} y={3} width={3} height={12} fill={tokens.text} />
          </G>
        </Svg>
        {!collapsed && (
          <View style={{ flex: 1 }}>
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 11,
                fontWeight: '700',
                letterSpacing: 1.4,
                color: tokens.text,
              }}
            >
              BROADCAST
            </Text>
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 11,
                fontWeight: '700',
                letterSpacing: 1.4,
                color: tokens.text,
                marginTop: 1,
              }}
            >
              BRAIN
            </Text>
          </View>
        )}
      </View>

      {/* Nav items */}
      <View style={{ gap: 2, paddingHorizontal: collapsed ? 0 : 6 }}>
        {NAV.map((item) => (
          <NavButton
            key={item.id}
            item={item}
            active={active === item.id}
            onPress={() => onChange(item.id)}
            live={item.id === 'AGENT' && !!agentLive}
            collapsed={collapsed}
          />
        ))}
      </View>

      {/* Bottom: theme + collapse toggles */}
      <View style={{ marginTop: 'auto', paddingTop: 14, paddingHorizontal: collapsed ? 8 : 12, gap: 8 }}>
        <Pressable
          onPress={toggleTheme}
          style={({ hovered }: any) => ({
            height: 40,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: collapsed ? 'center' : 'flex-start',
            gap: 10,
            paddingHorizontal: collapsed ? 0 : 12,
            borderRadius: 6,
            backgroundColor: hovered ? tokens.bgSubtle : tokens.bgBase,
            borderWidth: 1,
            borderColor: tokens.border,
          })}
          accessibilityLabel={mode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
        >
          <ThemeIcon mode={mode} />
          {!collapsed && (
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 9,
                fontWeight: '700',
                letterSpacing: 1.2,
                color: tokens.textMuted,
              }}
            >
              {mode === 'dark' ? 'LIGHT MODE' : 'DARK MODE'}
            </Text>
          )}
        </Pressable>
        <Pressable
          onPress={() => setCollapsed((v) => !v)}
          style={({ hovered }: any) => ({
            height: 40,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: collapsed ? 'center' : 'flex-start',
            gap: 10,
            paddingHorizontal: collapsed ? 0 : 12,
            borderRadius: 6,
            backgroundColor: hovered ? tokens.bgSubtle : tokens.bgBase,
            borderWidth: 1,
            borderColor: tokens.border,
          })}
          accessibilityLabel={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {icons.chevron(tokens.textMuted, collapsed ? 'right' : 'left')}
          {!collapsed && (
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 9,
                fontWeight: '700',
                letterSpacing: 1.2,
                color: tokens.textMuted,
              }}
            >
              COLLAPSE
            </Text>
          )}
        </Pressable>
      </View>
    </View>
  );
}

function ThemeIcon({ mode }: { mode: 'dark' | 'light' }) {
  if (mode === 'dark') {
    // sun icon — clicking switches to light
    return (
      <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
        <Circle cx={12} cy={12} r={4} stroke={tokens.textMuted} strokeWidth={1.8} />
        <Path
          d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"
          stroke={tokens.textMuted}
          strokeWidth={1.8}
          strokeLinecap="round"
        />
      </Svg>
    );
  }
  // moon icon — clicking switches to dark
  return (
    <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
      <Path
        d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"
        stroke={tokens.textMuted}
        strokeWidth={1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

function NavButton({
  item, active, onPress, live, collapsed,
}: { item: NavItem; active: boolean; onPress: () => void; live?: boolean; collapsed: boolean }) {
  const color = active ? tokens.text : tokens.textMuted;

  if (collapsed) {
    return (
      <Pressable
        onPress={onPress}
        style={({ hovered }: any) => ({
          position: 'relative',
          paddingVertical: 12,
          alignItems: 'center',
          backgroundColor: active ? tokens.bgSubtle : hovered ? tokens.bgHover : 'transparent',
        })}
      >
        {active && (
          <View style={{ position: 'absolute', left: 0, top: 6, bottom: 6, width: 3, backgroundColor: tokens.live, borderRadius: 2 }} />
        )}
        {live && (
          <View
            style={{
              position: 'absolute',
              top: 8,
              right: 12,
              width: 8,
              height: 8,
              borderRadius: 4,
              backgroundColor: tokens.live,
              borderWidth: 1,
              borderColor: tokens.bgRaised,
            }}
          />
        )}
        {item.icon(color)}
      </Pressable>
    );
  }

  return (
    <Pressable
      onPress={onPress}
      style={({ hovered }: any) => ({
        position: 'relative',
        flexDirection: 'row',
        alignItems: 'center',
        gap: 12,
        paddingVertical: 10,
        paddingHorizontal: 10,
        borderRadius: 4,
        backgroundColor: active ? tokens.bgSubtle : hovered ? tokens.bgHover : 'transparent',
      })}
    >
      {active && (
        <View style={{ position: 'absolute', left: -6, top: 8, bottom: 8, width: 3, backgroundColor: tokens.live, borderRadius: 2 }} />
      )}
      {item.icon(color)}
      <View style={{ flex: 1 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 10,
            fontWeight: '700',
            letterSpacing: 1.2,
            color,
          }}
        >
          {item.label}
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 8,
            color: tokens.textSubtle,
            marginTop: 2,
            letterSpacing: 0.4,
          }}
        >
          {item.sub}
        </Text>
      </View>
      {live && (
        <View
          style={{
            width: 8,
            height: 8,
            borderRadius: 4,
            backgroundColor: tokens.live,
          }}
        />
      )}
    </Pressable>
  );
}

