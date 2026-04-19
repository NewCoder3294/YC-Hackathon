import React, { useCallback, useMemo, useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import { IPadFrame } from '../frame/IPadFrame';
import { SpottingBoard, TeamPanel } from '../feature1/SpottingBoard';
import { ModePickerCard } from '../feature1/ModePickerCard';
import { BoardEmptyState } from '../feature1/BoardEmptyState';
import { PlayerDetailDrawer } from '../feature1/PlayerDetailDrawer';
import { VoiceQueryButton } from '../feature1/VoiceQueryButton';
import { ARGENTINA_XI, FRANCE_XI, MESSI } from '../fixtures/players';
import { Density, Mode, PlayerCellData } from '../types';
import { FONT_MONO, tokens } from '../theme/tokens';

// The commentator's single-screen Feature 1 surface.
// Owns all interactive state: mode · density · pinned players · annotations · drawer.
export function SpottingBoardScreen() {
  const [mode, setMode]           = useState<Mode | null>(null);
  const [density, setDensity]     = useState<Density>('STANDARD');
  const [pinned, setPinned]       = useState<Set<string>>(new Set([MESSI.id]));
  const [annotations, setAnnot]   = useState<Record<string, string>>({});
  const [pickerOpen, setPicker]   = useState(true);
  const [drawerId, setDrawerId]   = useState<string | null>(null);
  const [listening, setListening] = useState(false);

  const allPlayers = useMemo(
    () => [...ARGENTINA_XI, ...FRANCE_XI],
    [],
  );
  const playerById = useMemo(() => {
    const m = new Map<string, PlayerCellData>();
    for (const p of allPlayers) m.set(p.id, p);
    return m;
  }, [allPlayers]);

  const togglePin = useCallback((id: string) => {
    setPinned((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }, []);

  const annotate = useCallback((id: string) => {
    if (Platform.OS === 'web') {
      const current = annotations[id] ?? '';
      const next = window.prompt(
        'Annotation (visible only to you — Gemma 4 reads it as context):',
        current,
      );
      if (next === null) return;
      setAnnot((prev) => {
        const copy = { ...prev };
        if (next.trim() === '') delete copy[id]; else copy[id] = next.trim();
        return copy;
      });
    }
  }, [annotations]);

  const pickMode = useCallback((m: Mode) => {
    setMode(m);
    setPicker(false);
  }, []);

  const home: TeamPanel = {
    nation: 'ARGENTINA',
    code: 'ARG · 4-3-3',
    formation: '4-3-3',
    players: ARGENTINA_XI,
    accent: tokens.text,
    pinnedIds: Array.from(pinned),
    annotationForId: annotations,
  };
  const away: TeamPanel = {
    nation: 'FRANCE',
    code: 'FRA · 4-2-3-1',
    formation: '4-2-3-1',
    players: FRANCE_XI,
    accent: tokens.textSubtle,
    pinnedIds: Array.from(pinned),
    annotationForId: annotations,
  };

  const drawerPlayer = drawerId ? playerById.get(drawerId) : null;

  return (
    <IPadFrame>
      <View style={{ flex: 1 }}>
        {mode ? (
          <SpottingBoard
            mode={mode}
            density={density}
            savedStyle
            home={home}
            away={away}
            onModeChipPress={() => setPicker(true)}
            onDensityChange={setDensity}
            onTogglePin={togglePin}
            onAnnotate={annotate}
            onPlayerPress={(id) => setDrawerId(id)}
          />
        ) : (
          <BoardEmptyState onBuild={() => setPicker(true)} />
        )}

        {/* Voice query button — pinned to the bottom bezel */}
        {mode && !pickerOpen && (
          <VoiceQueryButton
            listening={listening}
            onPress={() => setListening((l) => !l)}
          />
        )}

        {/* Player detail drawer */}
        {drawerPlayer && (
          <PlayerDetailDrawer
            player={drawerPlayer}
            pinned={pinned.has(drawerPlayer.id)}
            annotation={annotations[drawerPlayer.id]}
            onClose={() => setDrawerId(null)}
            onTogglePin={() => togglePin(drawerPlayer.id)}
            onAnnotate={() => annotate(drawerPlayer.id)}
          />
        )}

        {/* Mode picker overlay — no backdrop tint; card carries its own boxShadow */}
        {pickerOpen && (
          <View
            style={{
              position: 'absolute',
              top: -28,
              left: 0,
              right: 0,
              bottom: 0,
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 30,
            }}
          >
            <Pressable
              style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
              onPress={mode ? () => setPicker(false) : undefined}
            />
            <ModePickerCard onPick={pickMode} onSkip={mode ? () => setPicker(false) : undefined} />
            {mode && (
              <Pressable onPress={() => setPicker(false)} style={{ marginTop: 14 }}>
                <Text
                  style={{
                    fontFamily: FONT_MONO,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: tokens.textMuted,
                  }}
                >
                  ESC · KEEP CURRENT MODE
                </Text>
              </Pressable>
            )}
          </View>
        )}
      </View>
    </IPadFrame>
  );
}
