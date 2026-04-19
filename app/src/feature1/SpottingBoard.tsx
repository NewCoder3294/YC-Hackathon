import React, { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { tokens } from '../theme/tokens';
import { Density, Mode, PlayerCellData } from '../types';
import { BoardHeader } from './BoardHeader';
import { TeamHeaderF1 } from './TeamHeaderF1';
import { PlayerCell } from './PlayerCell';
import { MiniPitch } from './MiniPitch';
import { PlayerSearch } from './PlayerSearch';

export type TeamPanel = {
  nation: string;
  code: string;
  formation: string;
  players: PlayerCellData[];
  accent: string;
  annotationForId?: Record<string, string>;
  pinnedIds?: string[];
};

type Props = {
  mode: Mode;
  density?: Density;
  modeChipLabel?: string;
  savedStyle?: boolean;
  showFormation?: boolean;
  showMiniPitches?: boolean;
  home: TeamPanel;
  away: TeamPanel;
  onModeChipPress?: () => void;
  onDensityChange?: (d: Density) => void;
  onTogglePin?: (id: string) => void;
  onAnnotate?: (id: string) => void;
  onPlayerPress?: (id: string) => void;
};

export function SpottingBoard({
  mode,
  density = 'STANDARD',
  modeChipLabel,
  savedStyle = false,
  showFormation = true,
  showMiniPitches = false,
  home,
  away,
  onModeChipPress,
  onDensityChange,
  onTogglePin,
  onAnnotate,
  onPlayerPress,
}: Props) {
  const label = modeChipLabel ?? (mode === 'STATS' ? 'STATS-FIRST' : mode === 'STORY' ? 'STORY-FIRST' : 'TACTICAL');

  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      <BoardHeader
        mode={label}
        density={density}
        savedStyle={savedStyle}
        onModeChipPress={onModeChipPress}
        onDensityChange={onDensityChange}
      />
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <TeamColumn
          panel={home}
          mode={mode}
          density={density}
          showFormation={showFormation}
          showMiniPitch={showMiniPitches}
          onTogglePin={onTogglePin}
          onAnnotate={onAnnotate}
          onPlayerPress={onPlayerPress}
        />
        <View style={{ width: 1, backgroundColor: tokens.borderSoft }} />
        <TeamColumn
          panel={away}
          mode={mode}
          density={density}
          showFormation={showFormation}
          showMiniPitch={showMiniPitches}
          onTogglePin={onTogglePin}
          onAnnotate={onAnnotate}
          onPlayerPress={onPlayerPress}
        />
      </View>
    </View>
  );
}

function TeamColumn({
  panel,
  mode,
  density,
  showFormation,
  showMiniPitch,
  onTogglePin,
  onAnnotate,
  onPlayerPress,
}: {
  panel: TeamPanel;
  mode: Mode;
  density: Density;
  showFormation: boolean;
  showMiniPitch: boolean;
  onTogglePin?: (id: string) => void;
  onAnnotate?: (id: string) => void;
  onPlayerPress?: (id: string) => void;
}) {
  const [filter, setFilter] = useState('');
  const { nation, code, formation, players, accent, annotationForId, pinnedIds } = panel;
  const pinnedSet = new Set(pinnedIds ?? []);

  const filterLower = filter.trim().toLowerCase();
  const filtered = filterLower
    ? players.filter((p) => p.name.toLowerCase().includes(filterLower) || p.n.includes(filterLower))
    : players;

  // Pinned players bubble to the top for fast glance access.
  const sorted = [...filtered].sort((a, b) => {
    const ap = pinnedSet.has(a.id) ? 0 : 1;
    const bp = pinnedSet.has(b.id) ? 0 : 1;
    return ap - bp;
  });

  return (
    <View style={{ flex: 1 }}>
      <TeamHeaderF1
        nation={nation}
        code={code}
        formation={formation}
        count={players.length}
        accent={accent}
        showFormation={showFormation}
      />
      <PlayerSearch value={filter} onChange={setFilter} placeholder={`FILTER ${nation} PLAYERS…`} />
      {showMiniPitch && (
        <View
          style={{
            padding: 12,
            borderBottomWidth: 1,
            borderBottomColor: tokens.borderSoft,
            alignItems: 'flex-start',
          }}
        >
          <MiniPitch formation={formation} nation={nation.slice(0, 3) as 'ARG' | 'FRA'} />
        </View>
      )}
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 12, gap: 8, paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
      >
        {sorted.map((p) => {
          const annotated = annotationForId?.[p.id];
          const data: PlayerCellData = {
            ...p,
            pinned: pinnedSet.has(p.id) || p.pinned,
            annotation: annotated ?? p.annotation ?? null,
          };
          return (
            <PlayerCell
              key={p.id}
              mode={mode}
              data={data}
              density={density}
              onTogglePin={onTogglePin}
              onAnnotate={onAnnotate}
              onPress={onPlayerPress}
            />
          );
        })}
      </ScrollView>
    </View>
  );
}
