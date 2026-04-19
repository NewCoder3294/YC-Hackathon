import React from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { PlayerCellData } from '../types';
import { SportradarBadge } from '../frame/SportradarBadge';

type Props = {
  player: PlayerCellData;
  pinned: boolean;
  onClose: () => void;
  onTogglePin: () => void;
  onAnnotate: () => void;
  annotation?: string;
};

// Full-height right-side drawer. Shows the merged projections (stats + story
// + tactical) for a player, plus career context. Replaces the "tap cell →
// full profile takes over" interaction in SPEC §Feature 1.
export function PlayerDetailDrawer({
  player, pinned, onClose, onTogglePin, onAnnotate, annotation,
}: Props) {
  const { n, name, pos, age, xg, xa, prog, pressures, shotAcc, rank,
          storyHero, storyLines = [], formationRole, role,
          defActions, keyPasses, pressingMap } = player;

  return (
    <View
      style={{
        position: 'absolute',
        top: 0, right: 0, bottom: 0,
        width: '38%',
        minWidth: 420,
        backgroundColor: tokens.bgRaised,
        borderLeftWidth: 1,
        borderLeftColor: tokens.border,
        boxShadow: '-14px 0 40px rgba(0,0,0,0.6)',
        zIndex: 20,
      }}
    >
      {/* Header */}
      <View
        style={{
          paddingVertical: 18,
          paddingHorizontal: 22,
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          flexDirection: 'row',
          alignItems: 'flex-start',
          gap: 14,
        }}
      >
        <View
          style={{
            width: 48, height: 48, borderRadius: 5,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1, borderColor: tokens.border,
            alignItems: 'center', justifyContent: 'center',
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 18, fontWeight: '700', color: tokens.text }}>{n}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 16, fontWeight: '700', color: tokens.text, letterSpacing: -0.16 }}>
            {name}
          </Text>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 4, flexWrap: 'wrap' }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.4 }}>
              {pos}{age ? ` · AGE ${age}` : ''}
            </Text>
            {rank && (
              <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.verified, letterSpacing: 1.4 }}>
                · {rank}
              </Text>
            )}
          </View>
        </View>
        <Pressable onPress={onClose} hitSlop={10} style={{ padding: 4 }}>
          <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
            <Path d="M6 6l12 12M18 6l-12 12" stroke={tokens.textMuted} strokeWidth={1.6} strokeLinecap="round" />
          </Svg>
        </Pressable>
      </View>

      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 22, gap: 22 }}>
        {/* Pin + annotate actions */}
        <View style={{ flexDirection: 'row', gap: 10 }}>
          <Pressable
            onPress={onTogglePin}
            style={{
              flex: 1,
              paddingVertical: 10,
              borderRadius: 6,
              borderWidth: 1,
              borderColor: pinned ? tokens.verified : tokens.border,
              backgroundColor: pinned ? 'rgba(16,185,129,0.08)' : tokens.bgSubtle,
              alignItems: 'center',
            }}
          >
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 11,
                fontWeight: '700',
                letterSpacing: 1.8,
                color: pinned ? tokens.verified : tokens.text,
              }}
            >
              {pinned ? '📌 PINNED — LIVE PRIORITY' : '📌 PIN FOR LIVE WHISPER'}
            </Text>
          </Pressable>
          <Pressable
            onPress={onAnnotate}
            style={{
              flex: 1,
              paddingVertical: 10,
              borderRadius: 6,
              borderWidth: 1,
              borderColor: tokens.border,
              backgroundColor: tokens.bgSubtle,
              alignItems: 'center',
            }}
          >
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 11,
                fontWeight: '700',
                letterSpacing: 1.8,
                color: tokens.text,
              }}
            >
              {annotation ? '✎  EDIT ANNOTATION' : '+  ADD ANNOTATION'}
            </Text>
          </Pressable>
        </View>

        {annotation && (
          <View
            style={{
              padding: 12,
              backgroundColor: tokens.stickyBg,
              borderRadius: 3,
              transform: [{ rotate: '-0.8deg' }],
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.8, color: 'rgba(61,45,10,0.6)', fontWeight: '700' }}>
              MY NOTE
            </Text>
            <Text
              style={{
                fontFamily: 'Marker Felt, Comic Sans MS, cursive',
                fontSize: 13,
                marginTop: 4,
                color: tokens.stickyText,
                lineHeight: 17,
              }}
            >
              {annotation}
            </Text>
          </View>
        )}

        {/* Story */}
        {storyHero && (
          <Section title="STORY">
            <Text style={{ fontFamily: FONT_MONO, fontSize: 15, fontWeight: '600', color: tokens.text, lineHeight: 21 }}>
              {storyHero}
            </Text>
            {storyLines.length > 0 && (
              <View style={{ gap: 6, marginTop: 10 }}>
                {storyLines.map((l, i) => (
                  <View key={i} style={{ paddingLeft: 10, borderLeftWidth: 1, borderLeftColor: tokens.borderSoft }}>
                    <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, fontStyle: 'italic', lineHeight: 17 }}>
                      {l}
                    </Text>
                  </View>
                ))}
              </View>
            )}
          </Section>
        )}

        {/* Tournament stats */}
        {(xg || xa || prog !== undefined || pressures !== undefined) && (
          <Section title="TOURNAMENT STATS (thru SF)">
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', rowGap: 14, columnGap: 14 }}>
              <Stat label="xG"         value={xg}       accent={tokens.verified} />
              <Stat label="xA"         value={xa} />
              <Stat label="PROG CARRY" value={prog} />
              <Stat label="PRESSURES"  value={pressures} />
              <Stat label="SHOT %"     value={shotAcc} />
              <Stat label="PPDA"       value="—" />
            </View>
            <View style={{ marginTop: 12 }}><SportradarBadge small /></View>
          </Section>
        )}

        {/* Tactical */}
        {(role || formationRole) && (
          <Section title="TACTICAL ROLE">
            {formationRole && (
              <Text
                style={{
                  fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.8,
                  color: tokens.esoteric, marginBottom: 6,
                }}
              >
                {formationRole}
              </Text>
            )}
            {role && (
              <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, lineHeight: 17 }}>{role}</Text>
            )}
            <View style={{ flexDirection: 'row', gap: 14, marginTop: 14 }}>
              <Stat label="DEF ACTIONS" value={defActions} accent={tokens.esoteric} />
              <Stat label="KEY PASSES"  value={keyPasses}  accent={tokens.esoteric} />
              <Stat label="PRESS ZONE"  value={pressingMap} accent={tokens.esoteric} />
            </View>
          </Section>
        )}

        {/* Placeholder: career / last-5 / H2H — wired once backend provides the data */}
        <Section title="CAREER · LAST-5 · H2H">
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textSubtle, lineHeight: 16 }}>
            Career splits, last-5-match form, and head-to-head vs today's opponents populate from
            match_cache.json once the data track lands. Sportradar ✓ / StatsBomb ✓ cited per row.
          </Text>
        </Section>
      </ScrollView>
    </View>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View>
      <Text
        style={{
          fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.8,
          color: tokens.textSubtle, marginBottom: 10,
        }}
      >
        {title}
      </Text>
      {children}
    </View>
  );
}

function Stat({ label, value, accent }: { label: string; value?: string | number; accent?: string }) {
  return (
    <View style={{ flex: 1, minWidth: '30%' }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.4, color: tokens.textSubtle }}>{label}</Text>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 24,
          fontWeight: '700',
          color: accent ?? tokens.text,
          marginTop: 2,
          letterSpacing: -0.48,
          lineHeight: 26,
          fontVariant: ['tabular-nums'] as any,
        }}
      >
        {value ?? '—'}
      </Text>
    </View>
  );
}
