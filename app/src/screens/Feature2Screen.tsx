import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { IPadFrame } from '../frame/IPadFrame';
import { FONT_MONO, tokens } from '../theme/tokens';
import { LivePaneShell, VoiceBezel } from '../feature2/LivePaneShell';
import {
  CounterNarrativeCard,
  PrecedentCard,
  ScorerStatCard,
} from '../feature2/CardStack';
import { MatchEvent, MomentumTag, RunningScorePanel, StoryItem, StoryQueue, TranscriptOverlay } from '../feature2/LivePanels';
import { VoiceWidget, WidgetRow } from '../feature2/VoiceWidget';
import { ActivePlayersPane } from '../feature2/ActivePlayersPane';
import { INITIAL_STORIES, MATCH_BEATS, MatchBeat } from '../fixtures/match';

type Phase = 'PRE-MATCH' | 'LIVE' | 'HALF-TIME' | 'FULL-TIME';

// Static voice-query response — simulates what Gemma 4 would return for
// "Show me Mbappé's record in WC finals".
const DEMO_VOICE_QUERY = "Show me Mbappé's record in WC finals";
const DEMO_VOICE_WIDGET: WidgetRow[] = [
  { year: '2018', opponent: 'CRO',     result: 'W 4-2',        note: '1 goal · Golden Ball finalist at 19' },
  { year: '2022', opponent: 'ARG',     result: '— IN PROGRESS', note: 'Brace so far · chasing Golden Boot', flag: true },
];

export function Feature2Screen() {
  // Match simulation state
  const [phase, setPhase]       = useState<Phase>('PRE-MATCH');
  const [clock, setClock]       = useState("00'");
  const [score, setScore]       = useState({ arg: 0, fra: 0 });
  const [events, setEvents]     = useState<MatchEvent[]>([]);
  const [stories, setStories]   = useState<StoryItem[]>(INITIAL_STORIES);
  const [momentum, setMomentum] = useState<MomentumTag | undefined>(undefined);
  const [beatIdx, setBeatIdx]   = useState(0);
  const [activeCard, setCard]   = useState<MatchBeat | null>(null);
  const [simRunning, setSim]    = useState(false);

  // Voice query simulation state
  const [listening, setListening]     = useState(false);
  const [transcript, setTranscript]   = useState<string | null>(null);
  const [widget, setWidget]           = useState<WidgetRow[] | null>(null);
  const [widgetPinned, setPinned]     = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startedAt = useRef<number>(0);

  // Reset sim + state
  const resetSim = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    timerRef.current = null;
    setPhase('PRE-MATCH');
    setClock("00'");
    setScore({ arg: 0, fra: 0 });
    setEvents([]);
    setStories(INITIAL_STORIES);
    setMomentum(undefined);
    setBeatIdx(0);
    setCard(null);
    setSim(false);
  }, []);

  // Drive the simulation: every 100ms tick, advance clock by 0.1 demo-seconds,
  // fire beats at their `at` offsets. Compression ratio is just for demo feel.
  const tickBeats = useCallback((elapsed: number) => {
    setBeatIdx((idx) => {
      let nextIdx = idx;
      while (nextIdx < MATCH_BEATS.length && MATCH_BEATS[nextIdx].at <= elapsed) {
        const beat = MATCH_BEATS[nextIdx];
        if (beat.score)    setScore(beat.score);
        if (beat.momentum) setMomentum(beat.momentum);
        if (beat.storyTickId) {
          setStories((prev) =>
            prev.map((s) => (s.id === beat.storyTickId ? { ...s, state: 'done' as const } : s)),
          );
        }
        setEvents((prev) => [
          ...prev,
          { minute: beat.minute, label: beat.label, score: `${beat.score?.arg ?? score.arg}-${beat.score?.fra ?? score.fra}`, color: beat.color },
        ]);
        if (beat.card) setCard(beat);
        nextIdx += 1;
      }
      return nextIdx;
    });
  }, [score.arg, score.fra]);

  useEffect(() => {
    if (!simRunning) return;
    timerRef.current = setInterval(() => {
      const elapsed = (Date.now() - startedAt.current) / 1000;
      // Clock: 1 demo-second = ~7 match-minutes so the compressed 12s hits FT.
      const matchMins = Math.min(90, Math.floor(elapsed * 7.5));
      setClock(`${String(matchMins).padStart(2, '0')}'`);
      tickBeats(elapsed);
      if (elapsed > MATCH_BEATS[MATCH_BEATS.length - 1].at + 2) {
        if (timerRef.current) clearInterval(timerRef.current);
        timerRef.current = null;
        setSim(false);
        setPhase('HALF-TIME');
      }
    }, 100);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [simRunning, tickBeats]);

  const startSim = useCallback(() => {
    resetSim();
    startedAt.current = Date.now();
    setPhase('LIVE');
    setSim(true);
    // After a tiny delay so reset state is visible
  }, [resetSim]);

  // Voice press-and-hold: show listening state, then on release simulate the
  // Gemma 4 widget materializing after ~800ms.
  const voicePress = useCallback(() => setListening(true), []);
  const voiceRelease = useCallback(() => {
    setListening(false);
    setTranscript(DEMO_VOICE_QUERY);
    setTimeout(() => {
      setWidget(DEMO_VOICE_WIDGET);
    }, 700);
  }, []);
  const dismissWidget = useCallback(() => {
    setWidget(null);
    setTranscript(null);
    setPinned(false);
  }, []);

  const phaseColor =
    phase === 'LIVE' ? tokens.live
    : phase === 'HALF-TIME' ? tokens.esoteric
    : tokens.textMuted;

  const latestCard = activeCard;
  const firedBeats = MATCH_BEATS.slice(0, beatIdx);
  const focusedPlayerId = latestCard?.scorerId;

  return (
    <IPadFrame>
      <LivePaneShell
        clock={clock}
        score={score}
        phase={phase}
        phaseColor={phaseColor}
        listening={listening}
        latency="842ms"
        hideBottomBezel
        rightSlot={<SimControls simRunning={simRunning} onStart={startSim} onReset={resetSim} />}
      >
        <View style={{ flex: 1, flexDirection: 'row', marginHorizontal: -20, marginVertical: -14 }}>
          {/* LEFT — active players */}
          <View style={{ flex: 0.55, borderRightWidth: 1, borderRightColor: tokens.border }}>
            <ActivePlayersPane
              firedBeats={firedBeats}
              clock={clock}
              listeningPlayerId={focusedPlayerId}
            />
          </View>

          {/* RIGHT — whisper agent */}
          <View style={{ flex: 0.45, backgroundColor: tokens.bgBase }}>
            <View
              style={{
                paddingVertical: 14,
                paddingHorizontal: 18,
                borderBottomWidth: 1,
                borderBottomColor: tokens.borderSoft,
                backgroundColor: tokens.bgRaised,
                flexDirection: 'row',
                alignItems: 'center',
                gap: 10,
              }}
            >
              <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: tokens.verified }} />
              <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 2.2, color: tokens.text }}>
                WHISPER AGENT
              </Text>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 0.4, marginLeft: 6 }}>
                Gemma 4 · on-device · &lt;1s
              </Text>
            </View>
            <ScrollView
              style={{ flex: 1 }}
              contentContainerStyle={{ padding: 14, gap: 12, paddingBottom: 8 }}
              showsVerticalScrollIndicator={false}
            >
              {/* Voice-triggered overlay + widget */}
              {transcript && <TranscriptOverlay text={transcript} agoMs={800} />}
              {widget && (
                <VoiceWidget
                  title="Mbappé — record in WC Finals (2018 · 2022)"
                  rows={widget}
                  pinned={widgetPinned}
                  onTogglePin={() => setPinned((p) => !p)}
                  onDismiss={dismissWidget}
                />
              )}

              {/* Autonomous 3-card stack for the most recent beat */}
              {latestCard?.card ? (
                <>
                  <ScorerStatCard {...latestCard.card.stat} />
                  <PrecedentCard {...latestCard.card.precedent} />
                  <CounterNarrativeCard {...latestCard.card.counter} />
                </>
              ) : (
                <EmptyStackPlaceholder phase={phase} />
              )}

              {/* Running score */}
              <RunningScorePanel
                events={events}
                momentum={momentum}
                preKickoffLabel={phase === 'PRE-MATCH' ? 'KICK-OFF · TAP "▶ SIMULATE MATCH"' : undefined}
              />

              {/* Story queue */}
              <StoryQueue items={stories} />
            </ScrollView>

            {/* Press-to-talk — anchored to the whisper column only */}
            <VoiceBezel
              listening={listening}
              latency="842ms"
              onPress={voicePress}
              onRelease={voiceRelease}
            />
          </View>
        </View>
      </LivePaneShell>
    </IPadFrame>
  );
}

function SimControls({
  simRunning, onStart, onReset,
}: { simRunning: boolean; onStart: () => void; onReset: () => void }) {
  return (
    <View style={{ flexDirection: 'row', gap: 6 }}>
      <Pressable
        onPress={onStart}
        style={{
          paddingVertical: 5,
          paddingHorizontal: 10,
          borderRadius: 4,
          backgroundColor: simRunning ? tokens.bgSubtle : tokens.live,
          borderWidth: 1,
          borderColor: simRunning ? tokens.border : tokens.live,
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.4, color: simRunning ? tokens.textMuted : '#fff' }}>
          {simRunning ? '▶ RUNNING…' : '▶ SIMULATE MATCH'}
        </Text>
      </Pressable>
      <Pressable
        onPress={onReset}
        style={{
          paddingVertical: 5,
          paddingHorizontal: 10,
          borderRadius: 4,
          backgroundColor: tokens.bgSubtle,
          borderWidth: 1,
          borderColor: tokens.border,
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.4, color: tokens.textMuted }}>
          ↻ RESET
        </Text>
      </Pressable>
    </View>
  );
}

function EmptyStackPlaceholder({ phase }: { phase: Phase }) {
  return (
    <View
      style={{
        paddingVertical: 26,
        paddingHorizontal: 20,
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderStyle: 'dashed',
        borderColor: tokens.borderSoft,
        borderRadius: 8,
        alignItems: 'center',
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.textSubtle, fontWeight: '700' }}>
        {phase === 'PRE-MATCH' ? 'WAITING FOR KICKOFF' : 'WAITING FOR NEXT EVENT'}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 8, textAlign: 'center', maxWidth: 360, lineHeight: 15 }}>
        Gemma 4 listens continuously. When something stat-worthy happens, a 3-card stack materializes here —
        under a second, from on-device.
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, marginTop: 10, letterSpacing: 1.4 }}>
        · OR HOLD THE VOICE BUTTON TO ASK ANYTHING ·
      </Text>
    </View>
  );
}
