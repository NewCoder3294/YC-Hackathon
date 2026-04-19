import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { SportradarBadge } from '../frame/SportradarBadge';

export type WidgetRow = {
  year: string;
  opponent: string;
  result: string;                // "W 4-2", "L 1-0 (ET)", etc.
  note?: string;
  flag?: boolean;                // amber attention row
};

type Props = {
  title: string;
  rows: WidgetRow[];
  pinned?: boolean;
  onTogglePin?: () => void;
  onDismiss?: () => void;
};

// The pinnable widget materialized by a voice command like "Show me Mbappé's
// WC final record". Horizontal timeline layout — year · opponent · result · note.
export function VoiceWidget({ title, rows, pinned = false, onTogglePin, onDismiss }: Props) {
  return (
    <View
      style={{
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 10,
        paddingTop: 12,
        paddingBottom: 14,
        paddingHorizontal: 14,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Svg viewBox="0 0 24 24" width={13} height={13} fill="none">
            <Rect x={9} y={2} width={6} height={12} rx={3} stroke={tokens.live} strokeWidth={1.75} />
            <Path d="M5 10v1a7 7 0 0 0 14 0v-1" stroke={tokens.live} strokeWidth={1.75} strokeLinecap="round" />
          </Svg>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.live }}>
            VOICE · WIDGET
          </Text>
        </View>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <WidgetBtn active={pinned} label="PIN" onPress={onTogglePin} />
          <WidgetBtn label="✕" onPress={onDismiss} />
        </View>
      </View>

      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '600', color: tokens.text, marginBottom: 10, letterSpacing: 0.1 }}>
        {title}
      </Text>

      <View>
        {rows.map((r, i) => (
          <View
            key={`${r.year}-${r.opponent}`}
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: 8,
              paddingVertical: 6,
              borderTopWidth: i === 0 ? 0 : 1,
              borderTopColor: tokens.borderSoft,
            }}
          >
            <Text
              style={{
                fontFamily: FONT_MONO,
                width: 54,
                fontSize: 11,
                color: tokens.textSubtle,
                letterSpacing: 0.6,
                fontVariant: ['tabular-nums'] as any,
              }}
            >
              {r.year}
            </Text>
            <Text style={{ fontFamily: FONT_MONO, width: 90, fontSize: 11, color: tokens.text, letterSpacing: 0.2 }}>
              {r.opponent}
            </Text>
            <Text
              style={{
                fontFamily: FONT_MONO,
                width: 70,
                fontSize: 11,
                fontWeight: '600',
                letterSpacing: 0.6,
                fontVariant: ['tabular-nums'] as any,
                color:
                  r.result.startsWith('W') ? tokens.verified
                  : r.result.startsWith('L') ? tokens.live
                  : tokens.textMuted,
              }}
            >
              {r.result}
            </Text>
            <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center' }}>
              {r.flag && (
                <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.esoteric, marginRight: 6 }}>⚠</Text>
              )}
              <Text
                style={{
                  fontFamily: FONT_MONO,
                  fontSize: 10,
                  color: r.flag ? tokens.esoteric : tokens.textMuted,
                  letterSpacing: 0.2,
                  flex: 1,
                }}
              >
                {r.note}
              </Text>
            </View>
          </View>
        ))}
      </View>

      <View style={{ marginTop: 10, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <SportradarBadge small />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.4, color: tokens.textSubtle }}>
          tap row → expand
        </Text>
      </View>
    </View>
  );
}

function WidgetBtn({ label, active, onPress }: { label: string; active?: boolean; onPress?: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      hitSlop={4}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 5,
        paddingVertical: 3,
        paddingHorizontal: 8,
        borderRadius: 3,
        backgroundColor: active ? 'rgba(16,185,129,0.1)' : tokens.bgSubtle,
        borderWidth: 1,
        borderColor: active ? tokens.verified : tokens.border,
      }}
    >
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 8,
          fontWeight: '700',
          letterSpacing: 1.8,
          color: active ? tokens.verified : tokens.textMuted,
        }}
      >
        {label === 'PIN' && active ? '📌 PINNED' : label}
      </Text>
    </Pressable>
  );
}
