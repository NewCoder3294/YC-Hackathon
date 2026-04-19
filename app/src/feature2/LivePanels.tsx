import React from 'react';
import { Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { EmptyGridlines } from './atoms';

export type MatchEvent = {
  minute: string;
  label: string;
  score: string;
  color?: string;
};

export type MomentumTag = {
  label: string;
  color: string;
};

// Timeline of what's happened in the match so far.
export function RunningScorePanel({
  events = [],
  momentum,
  preKickoffLabel,
}: {
  events?: MatchEvent[];
  momentum?: MomentumTag;
  preKickoffLabel?: string;
}) {
  return (
    <View
      style={{
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingVertical: 10,
        paddingHorizontal: 14,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.textSubtle }}>
          RUNNING SCORE
        </Text>
        {momentum && (
          <View
            style={{
              paddingVertical: 3,
              paddingHorizontal: 7,
              backgroundColor: `${momentum.color}20`,
              borderWidth: 1,
              borderColor: `${momentum.color}70`,
              borderRadius: 3,
            }}
          >
            <Text
              style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.8, color: momentum.color }}
            >
              {momentum.label}
            </Text>
          </View>
        )}
      </View>
      {events.length === 0 ? (
        <EmptyGridlines label={preKickoffLabel} />
      ) : (
        <View style={{ gap: 5 }}>
          {events.map((e, i) => (
            <View key={i} style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <Text
                style={{
                  fontFamily: FONT_MONO,
                  width: 44,
                  fontSize: 11,
                  color: tokens.textSubtle,
                  letterSpacing: 0.6,
                  fontVariant: ['tabular-nums'] as any,
                }}
              >
                {e.minute}
              </Text>
              <View style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: e.color ?? tokens.text }} />
              <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.text, flex: 1, letterSpacing: 0.2 }}>
                {e.label}
              </Text>
              <Text
                style={{
                  fontFamily: FONT_MONO,
                  fontSize: 10,
                  color: tokens.textSubtle,
                  fontVariant: ['tabular-nums'] as any,
                }}
              >
                {e.score}
              </Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

export type StoryItem = {
  id: string;
  text: string;
  state: 'pending' | 'done';
  nudge?: boolean;
};

// Pre-planned storylines. STT ticks off matches when the commentator mentions them.
// AI NUDGE chip appears on items that haven't been touched in a while.
export function StoryQueue({ items, title = 'STORY QUEUE' }: { items: StoryItem[]; title?: string }) {
  const doneCount = items.filter((i) => i.state === 'done').length;
  return (
    <View
      style={{
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        paddingVertical: 10,
        paddingHorizontal: 14,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 2.2, color: tokens.textSubtle }}>
          {title}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.4, color: tokens.textSubtle }}>
          {doneCount}/{items.length}
        </Text>
      </View>
      <View style={{ gap: 5 }}>
        {items.map((it) => {
          const done = it.state === 'done';
          return (
            <View key={it.id} style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <Checkbox done={done} />
              <Text
                style={{
                  fontFamily: FONT_MONO,
                  fontSize: 11,
                  color: done ? tokens.textSubtle : tokens.text,
                  lineHeight: 15,
                  flex: 1,
                  textDecorationLine: done ? 'line-through' : 'none',
                }}
              >
                {it.text}
              </Text>
              {it.nudge && <NudgeChip />}
            </View>
          );
        })}
      </View>
    </View>
  );
}

function Checkbox({ done }: { done: boolean }) {
  return (
    <Svg viewBox="0 0 14 14" width={12} height={12}>
      <Rect
        width={14}
        height={14}
        rx={2}
        fill="none"
        stroke={done ? tokens.verified : tokens.border}
        strokeWidth={1}
      />
      {done && (
        <Path
          d="M3.5 7.5l2.5 2.5 5-5"
          stroke={tokens.verified}
          strokeWidth={1.5}
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      )}
    </Svg>
  );
}

function NudgeChip() {
  return (
    <View
      style={{
        paddingVertical: 2,
        paddingHorizontal: 6,
        borderRadius: 3,
        backgroundColor: 'rgba(245,158,11,0.1)',
        borderWidth: 1,
        borderColor: 'rgba(245,158,11,0.4)',
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.8, color: tokens.esoteric }}>
        AI NUDGE
      </Text>
    </View>
  );
}

// "You said: …" transcript bubble shown while answering voice commands.
export function TranscriptOverlay({ text, agoMs }: { text: string; agoMs?: number }) {
  const ago = agoMs !== undefined ? `${(agoMs / 1000).toFixed(1)}s ago` : 'just now';
  return (
    <View
      style={{
        paddingVertical: 10,
        paddingHorizontal: 14,
        borderWidth: 1,
        borderColor: tokens.live,
        backgroundColor: 'rgba(239,68,68,0.06)',
        borderRadius: 8,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
      }}
    >
      <Svg viewBox="0 0 24 24" width={14} height={14} fill="none">
        <Rect x={9} y={2} width={6} height={12} rx={3} stroke={tokens.live} strokeWidth={1.75} />
        <Path d="M5 10v1a7 7 0 0 0 14 0v-1" stroke={tokens.live} strokeWidth={1.75} strokeLinecap="round" />
      </Svg>
      <View style={{ flex: 1 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 2, color: tokens.live, marginBottom: 2 }}>
          YOU ASKED · {ago}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.text, lineHeight: 16, fontStyle: 'italic' }}>
          "{text}"
        </Text>
      </View>
    </View>
  );
}
