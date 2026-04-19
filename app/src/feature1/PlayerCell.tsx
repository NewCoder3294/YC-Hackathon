import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';
import { Density, Mode, PlayerCellData } from '../types';
import { SportradarBadge } from '../frame/SportradarBadge';
import { StickyAnnotation } from './StickyAnnotation';

type Props = {
  mode: Mode;
  data: PlayerCellData;
  density?: Density;
  onTogglePin?: (id: string) => void;
  onAnnotate?: (id: string) => void;
  onPress?: (id: string) => void;
};

export function PlayerCell({ mode, data, density = 'STANDARD', onTogglePin, onAnnotate, onPress }: Props) {
  const isCompact = density === 'COMPACT';
  const { id, n, name, pos, formationRole, rank, pinned, annotation } = data;
  const highlight = pinned || data.highlight;

  return (
    <Pressable
      onPress={() => onPress?.(id)}
      style={({ hovered, pressed }: any) => ({
        position: 'relative',
        backgroundColor: pressed
          ? tokens.bgHover
          : hovered
          ? tokens.bgSubtle
          : highlight
          ? tokens.bgSubtle
          : tokens.bgRaised,
        borderWidth: 1,
        borderColor: highlight ? tokens.border : tokens.borderSoft,
        borderRadius: 6,
        paddingVertical: isCompact ? 10 : 12,
        paddingHorizontal: isCompact ? 12 : 14,
        overflow: 'hidden',
      })}
    >
      {highlight && (
        <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, backgroundColor: tokens.live }} />
      )}

      {/* Header row: number | identity | pin */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        <View
          style={{
            width: 30,
            height: 30,
            borderRadius: 3,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1,
            borderColor: tokens.borderSoft,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', color: tokens.text }}>{n}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '600', color: tokens.text, letterSpacing: 0.24 }}>
            {name}
          </Text>
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2, flexWrap: 'wrap' }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>
              {mode === 'TACTICAL' && formationRole ? formationRole : pos}
            </Text>
            {mode === 'STATS' && rank && (
              <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.verified, letterSpacing: 1.3, marginLeft: 6 }}>
                · {rank}
              </Text>
            )}
          </View>
        </View>
        <Pressable
          onPress={(e: any) => {
            e?.stopPropagation?.();
            onTogglePin?.(id);
          }}
          hitSlop={6}
        >
          {pinned ? <PinBadge /> : <PinToggleStub />}
        </Pressable>
      </View>

      {/* Mode-specific body */}
      {!isCompact && mode === 'STATS' && <StatsBody data={data} />}
      {!isCompact && mode === 'STORY' && <StoryBody data={data} />}
      {!isCompact && mode === 'TACTICAL' && <TacticalBody data={data} />}

      {/* Compact collapse */}
      {isCompact && <CompactSummary mode={mode} data={data} />}

      {/* Sticky note annotation */}
      {annotation && <StickyAnnotation text={annotation} />}

      {/* Footer */}
      <View style={{ marginTop: 10, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
        <SportradarBadge small />
        {mode === 'STORY' && !annotation && onAnnotate && (
          <Pressable
            onPress={(e: any) => {
              e?.stopPropagation?.();
              onAnnotate(id);
            }}
            hitSlop={6}
          >
            <AddAnnotationBtn />
          </Pressable>
        )}
      </View>
    </Pressable>
  );
}

function StatsBody({ data }: { data: PlayerCellData }) {
  const { xg, xa, prog, pressures, shotAcc } = data;
  const Stat = ({ label, value, accent }: { label: string; value?: string | number; accent?: string }) => (
    <View style={{ flex: 1, minWidth: '32%' }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.4, color: tokens.textSubtle }}>{label}</Text>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 22,
          fontWeight: '700',
          color: accent ?? tokens.text,
          letterSpacing: -0.44,
          lineHeight: 24,
          fontVariant: ['tabular-nums'] as any,
        }}
      >
        {value ?? '—'}
      </Text>
    </View>
  );
  return (
    <View style={{ marginTop: 12, flexDirection: 'row', flexWrap: 'wrap', rowGap: 10, columnGap: 10 }}>
      <Stat label="xG" value={xg} accent={tokens.verified} />
      <Stat label="xA" value={xa} />
      <Stat label="PROG CARRY" value={prog} />
      <Stat label="PRESSURES" value={pressures} />
      <Stat label="SHOT %" value={shotAcc} />
      <Stat label="PPDA" value="—" />
    </View>
  );
}

function StoryBody({ data }: { data: PlayerCellData }) {
  const { age, storyHero, storyLines = [] } = data;
  return (
    <View style={{ marginTop: 10 }}>
      {storyHero && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 14, fontWeight: '600', color: tokens.text, lineHeight: 19 }}>
          {storyHero}
        </Text>
      )}
      {storyLines.length > 0 && (
        <View style={{ marginTop: 8, gap: 4 }}>
          {storyLines.map((l, i) => (
            <View key={i} style={{ paddingLeft: 10, borderLeftWidth: 1, borderLeftColor: tokens.borderSoft }}>
              <Text
                style={{
                  fontFamily: FONT_MONO,
                  fontSize: 11,
                  color: tokens.textMuted,
                  lineHeight: 15,
                  fontStyle: 'italic',
                }}
              >
                {l}
              </Text>
            </View>
          ))}
        </View>
      )}
      {age !== undefined && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3, marginTop: 8 }}>
          AGE {age}
        </Text>
      )}
    </View>
  );
}

function TacticalBody({ data }: { data: PlayerCellData }) {
  const { role, pressingMap, defActions, keyPasses } = data;
  return (
    <View style={{ marginTop: 10 }}>
      {role && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, letterSpacing: 0.8, lineHeight: 15 }}>
          {role}
        </Text>
      )}
      <View style={{ marginTop: 10, flexDirection: 'row', gap: 10 }}>
        <TacticalChip label="DEF ACTIONS" value={defActions} />
        <TacticalChip label="KEY PASSES" value={keyPasses} />
        <TacticalChip label="PRESS ZONE" value={pressingMap} />
      </View>
    </View>
  );
}

function TacticalChip({ label, value }: { label: string; value?: string | number }) {
  return (
    <View style={{ flex: 1 }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.4, color: tokens.textSubtle }}>{label}</Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', color: tokens.esoteric, marginTop: 2 }}>
        {value ?? '—'}
      </Text>
    </View>
  );
}

function CompactSummary({ mode, data }: { mode: Mode; data: PlayerCellData }) {
  const { xg, xa, prog, storyHero, role, defActions } = data;
  const text =
    mode === 'STATS'
      ? `${xg ?? '—'} xG · ${xa ?? '—'} xA · ${prog ?? '—'} prog`
      : mode === 'STORY'
      ? storyHero ?? '—'
      : `${role ?? '—'} · ${defActions ?? '—'} def actions`;
  return <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, marginTop: 8 }}>{text}</Text>;
}

export function PinBadge() {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 4,
        paddingVertical: 3,
        paddingHorizontal: 6,
        borderRadius: 3,
        backgroundColor: 'rgba(16,185,129,0.08)',
        borderWidth: 1,
        borderColor: 'rgba(16,185,129,0.3)',
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.3, color: tokens.verified }}>
        📌 PINNED
      </Text>
    </View>
  );
}

// Empty pin affordance — shown when the player is not pinned, acts as the tap target.
function PinToggleStub() {
  return (
    <View
      style={{
        width: 28,
        height: 18,
        borderRadius: 3,
        borderWidth: 1,
        borderStyle: 'dashed',
        borderColor: tokens.borderSoft,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle }}>📌</Text>
    </View>
  );
}

export function AddAnnotationBtn() {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 4,
        paddingVertical: 3,
        paddingHorizontal: 7,
        borderRadius: 3,
        backgroundColor: tokens.bgSubtle,
        borderWidth: 1,
        borderStyle: 'dashed',
        borderColor: tokens.border,
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.3, color: tokens.textMuted }}>
        + ANNOTATE
      </Text>
    </View>
  );
}
