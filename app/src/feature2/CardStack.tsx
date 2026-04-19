import React from 'react';
import { Text, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { SportradarBadge } from '../frame/SportradarBadge';
import { LatencyTag } from './atoms';

export type CardKind = 'stat' | 'precedent' | 'counter';

const EDGE: Record<CardKind, { edge: string; label: string }> = {
  stat:      { edge: tokens.text,     label: 'STAT' },
  precedent: { edge: tokens.verified, label: 'PRECEDENT' },
  counter:   { edge: tokens.esoteric, label: 'COUNTER-NARRATIVE' },
};

export function CardStack({ children }: { children: React.ReactNode }) {
  return <View style={{ gap: 8 }}>{children}</View>;
}

// Generic card chrome — left stripe + kind label, body is children.
export function StackCard({ kind, children }: { kind: CardKind; children: React.ReactNode }) {
  const { edge, label } = EDGE[kind];
  const labelColor = kind === 'stat' ? tokens.textSubtle : edge;
  return (
    <View
      style={{
        position: 'relative',
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingTop: 14,
        paddingBottom: 12,
        paddingLeft: 20,
        paddingRight: 16,
        overflow: 'hidden',
      }}
    >
      <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, backgroundColor: edge }} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: labelColor, marginBottom: 8 }}>
        {label}
      </Text>
      {children}
    </View>
  );
}

// Hero stat card — big numeral + player + context lines + Sportradar badge + latency.
type ScorerStatProps = {
  player: string;
  playerSub: string;
  minute: string;
  type: string;
  scoreChange: string;
  heroNumeral: string;
  heroCaption: string;
  context?: string[];
  latency?: string;
};

export function ScorerStatCard({
  player, playerSub, minute, type, scoreChange,
  heroNumeral, heroCaption, context = [], latency = '842ms',
}: ScorerStatProps) {
  return (
    <View
      style={{
        position: 'relative',
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingTop: 14,
        paddingBottom: 14,
        paddingLeft: 22,
        paddingRight: 18,
        overflow: 'hidden',
      }}
    >
      <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, backgroundColor: tokens.text }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: tokens.live }} />
          <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.textSubtle }}>
            STAT
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, letterSpacing: 1.4 }}>
            · {minute} · {type} · {scoreChange}
          </Text>
        </View>
        <LatencyTag ms={latency} />
      </View>

      <View style={{ marginTop: 10 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 2, color: tokens.textMuted }}>
          {player}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.3, color: tokens.textSubtle, marginTop: 2 }}>
          {playerSub}
        </Text>
      </View>

      <View style={{ marginTop: 6, flexDirection: 'row', alignItems: 'flex-end', gap: 14 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 88,
            fontWeight: '700',
            color: tokens.text,
            letterSpacing: -3.5,
            lineHeight: 80,
            fontVariant: ['tabular-nums'] as any,
          }}
        >
          {heroNumeral}
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 13,
            color: tokens.text,
            lineHeight: 17,
            maxWidth: 240,
            paddingBottom: 10,
          }}
        >
          {heroCaption}
        </Text>
      </View>

      <View style={{ marginTop: 12, gap: 4 }}>
        {context.map((c, i) => (
          <View key={i} style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textSubtle, marginRight: 6 }}>—</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, lineHeight: 15, flex: 1 }}>{c}</Text>
          </View>
        ))}
      </View>

      <View style={{ marginTop: 12 }}>
        <SportradarBadge small />
      </View>
    </View>
  );
}

// Historical pattern card.
export function PrecedentCard({ headline, support }: { headline: string; support?: string }) {
  return (
    <View
      style={{
        position: 'relative',
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingTop: 12,
        paddingBottom: 12,
        paddingLeft: 20,
        paddingRight: 14,
        overflow: 'hidden',
      }}
    >
      <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, backgroundColor: tokens.verified }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <Svg viewBox="0 0 24 24" width={12} height={12} fill="none">
          <Path d="M3 3v18h18" stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" />
          <Path d="M7 14l4-4 3 3 5-6" stroke={tokens.verified} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" />
        </Svg>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.verified }}>
          PRECEDENT
        </Text>
      </View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 14, color: tokens.text, lineHeight: 19, fontWeight: '500' }}>
        {headline}
      </Text>
      {support && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 0.4, marginTop: 6 }}>
          {support}
        </Text>
      )}
      <View style={{ marginTop: 10 }}>
        <SportradarBadge small />
      </View>
    </View>
  );
}

// Counter-narrative card — drama for the losing side's fans.
export function CounterNarrativeCard({
  forSide, headline, support,
}: { forSide: string; headline: string; support?: string }) {
  return (
    <View
      style={{
        position: 'relative',
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingTop: 12,
        paddingBottom: 12,
        paddingLeft: 20,
        paddingRight: 14,
        overflow: 'hidden',
      }}
    >
      <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, backgroundColor: tokens.esoteric }} />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <Svg viewBox="0 0 24 24" width={12} height={12} fill="none">
          <Path
            d="M12 2l3 7h7l-5.5 4.5 2 7L12 16l-6.5 4.5 2-7L2 9h7z"
            stroke={tokens.esoteric}
            strokeWidth={1.75}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </Svg>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.esoteric }}>
          COUNTER-NARRATIVE · FOR {forSide}
        </Text>
      </View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 13, color: tokens.text, lineHeight: 17 }}>{headline}</Text>
      {support && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 0.4, marginTop: 6 }}>
          {support}
        </Text>
      )}
      <View style={{ marginTop: 10 }}>
        <SportradarBadge small />
      </View>
    </View>
  );
}
