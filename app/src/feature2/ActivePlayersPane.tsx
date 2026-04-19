import React, { useMemo } from 'react';
import { ScrollView, Text, View } from 'react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { ARGENTINA_XI, FRANCE_XI } from '../fixtures/players';
import { PlayerCellData } from '../types';
import { MatchBeat } from '../fixtures/match';

// Live lineup pane — shows the commentator who's currently on the pitch and
// what each player has done in the match so far. Updates as simulated match
// beats fire: goal badges materialize on scorers, counts tally on repeats.

type PlayerEvent = { minute: string; kind: 'goal' };

function buildEventMap(firedBeats: MatchBeat[]): Map<string, PlayerEvent[]> {
  const m = new Map<string, PlayerEvent[]>();
  for (const beat of firedBeats) {
    if (beat.kind === 'goal' && beat.scorerId) {
      const list = m.get(beat.scorerId) ?? [];
      list.push({ minute: beat.minute, kind: 'goal' });
      m.set(beat.scorerId, list);
    }
  }
  return m;
}

type Props = {
  firedBeats: MatchBeat[];
  clock: string;
  listeningPlayerId?: string;   // "Gemma 4 is zoomed in on X"
};

export function ActivePlayersPane({ firedBeats, clock, listeningPlayerId }: Props) {
  const events = useMemo(() => buildEventMap(firedBeats), [firedBeats]);

  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      {/* Pane header */}
      <View
        style={{
          paddingVertical: 14,
          paddingHorizontal: 18,
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <View>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 2.2, color: tokens.text }}>
            ACTIVE LINEUP
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, marginTop: 3, letterSpacing: 0.4 }}>
            ARG vs FRA · 2022 WC FINAL
          </Text>
        </View>
        <View
          style={{
            paddingVertical: 4,
            paddingHorizontal: 8,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1,
            borderColor: tokens.border,
            borderRadius: 3,
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 1.4, color: tokens.textMuted }}>{clock}</Text>
        </View>
      </View>

      <View style={{ flex: 1, flexDirection: 'row' }}>
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingVertical: 12, paddingHorizontal: 12 }}
          showsVerticalScrollIndicator={false}
        >
          <TeamBlock
            nation="ARGENTINA"
            code="ARG · 4-3-3"
            accent={tokens.text}
            players={ARGENTINA_XI}
            events={events}
            listeningPlayerId={listeningPlayerId}
          />
        </ScrollView>
        <View style={{ width: 1, backgroundColor: tokens.borderSoft }} />
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingVertical: 12, paddingHorizontal: 12 }}
          showsVerticalScrollIndicator={false}
        >
          <TeamBlock
            nation="FRANCE"
            code="FRA · 4-2-3-1"
            accent={tokens.textMuted}
            players={FRANCE_XI}
            events={events}
            listeningPlayerId={listeningPlayerId}
          />
        </ScrollView>
      </View>
    </View>
  );
}

function TeamBlock({
  nation, code, accent, players, events, listeningPlayerId,
}: {
  nation: string;
  code: string;
  accent: string;
  players: PlayerCellData[];
  events: Map<string, PlayerEvent[]>;
  listeningPlayerId?: string;
}) {
  return (
    <View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <View style={{ width: 4, height: 18, backgroundColor: accent, borderRadius: 2 }} />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 1.8, color: tokens.text }}>
          {nation}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>{code}</Text>
        <View style={{ flex: 1 }} />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>
          {players.length} ON PITCH
        </Text>
      </View>

      <View style={{ gap: 5 }}>
        {players.map((p) => (
          <PlayerRow
            key={p.id}
            player={p}
            events={events.get(p.id) ?? []}
            listening={listeningPlayerId === p.id}
          />
        ))}
      </View>
    </View>
  );
}

function PlayerRow({
  player, events, listening,
}: { player: PlayerCellData; events: PlayerEvent[]; listening: boolean }) {
  const scored = events.some((e) => e.kind === 'goal');
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 7,
        paddingHorizontal: 10,
        backgroundColor: scored ? 'rgba(239,68,68,0.04)' : tokens.bgRaised,
        borderWidth: 1,
        borderColor: scored ? 'rgba(239,68,68,0.3)' : tokens.borderSoft,
        borderRadius: 5,
        gap: 10,
      }}
    >
      {/* Jersey number */}
      <View
        style={{
          width: 26,
          height: 26,
          borderRadius: 3,
          backgroundColor: tokens.bgSubtle,
          borderWidth: 1,
          borderColor: tokens.borderSoft,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', color: tokens.text }}>{player.n}</Text>
      </View>

      {/* Name + position */}
      <View style={{ flex: 1 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '600', color: tokens.text, letterSpacing: 0.2 }}>
          {player.name}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3, marginTop: 1 }}>
          {player.pos.split(' · ')[0]}
        </Text>
      </View>

      {/* Listening focus indicator */}
      {listening && (
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: 4,
            paddingVertical: 2,
            paddingHorizontal: 6,
            borderRadius: 3,
            backgroundColor: 'rgba(16,185,129,0.1)',
            borderWidth: 1,
            borderColor: 'rgba(16,185,129,0.4)',
          }}
        >
          <Svg width={8} height={8} viewBox="0 0 10 10">
            <Circle cx={5} cy={5} r={3} fill={tokens.verified} />
          </Svg>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.4, color: tokens.verified }}>
            FOCUS
          </Text>
        </View>
      )}

      {/* Event badges */}
      <View style={{ flexDirection: 'row', gap: 4 }}>
        {events.map((e, i) => (
          <GoalBadge key={i} minute={e.minute} />
        ))}
      </View>
    </View>
  );
}

function GoalBadge({ minute }: { minute: string }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 3,
        paddingVertical: 2,
        paddingHorizontal: 6,
        borderRadius: 3,
        backgroundColor: 'rgba(239,68,68,0.12)',
        borderWidth: 1,
        borderColor: 'rgba(239,68,68,0.5)',
      }}
    >
      <Svg width={10} height={10} viewBox="0 0 24 24" fill="none">
        <Circle cx={12} cy={12} r={9} stroke={tokens.live} strokeWidth={1.5} />
        <Path d="M12 3v18M3 12h18" stroke={tokens.live} strokeWidth={1} />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 0.5, color: tokens.live }}>
        {minute}
      </Text>
    </View>
  );
}
