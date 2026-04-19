import React from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, {
  Easing,
  FadeIn,
  FadeOut,
  Layout,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Circle, Path, Rect } from 'react-native-svg';
import { IPadFrame } from '../frame/IPadFrame';
import { FONT_MONO, tokens } from '../theme/tokens';
import { useAgent } from '../agent/AgentContext';

export function AgentScreen() {
  const { active, points, saving, start, stop } = useAgent();
  const [confirmStop, setConfirmStop] = React.useState(false);

  return (
    <IPadFrame>
      {saving ? (
        <SavingOverlay />
      ) : active ? (
        <ListeningUI points={points} onStop={() => setConfirmStop(true)} />
      ) : (
        <StartUI onStart={start} />
      )}
      {confirmStop && (
        <ConfirmStop
          onConfirm={() => {
            setConfirmStop(false);
            stop();
          }}
          onCancel={() => setConfirmStop(false)}
        />
      )}
    </IPadFrame>
  );
}

function ConfirmStop({ onConfirm, onCancel }: { onConfirm: () => void; onCancel: () => void }) {
  return (
    <View
      style={{
        position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
        backgroundColor: 'rgba(0,0,0,0.6)',
        alignItems: 'center', justifyContent: 'center',
        zIndex: 100,
      }}
    >
      <Pressable style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} onPress={onCancel} />
      <View
        style={{
          width: 460,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 10,
          paddingVertical: 22,
          paddingHorizontal: 24,
          boxShadow: tokens.shadowStrong,
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.live, fontWeight: '700' }}>
          END SESSION?
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 20, fontWeight: '700', color: tokens.text, marginTop: 8, letterSpacing: -0.2 }}>
          Are you sure you want to stop?
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, marginTop: 8, lineHeight: 17 }}>
          I'll save everything to your Archive — the point feed and a post-match summary note. You can keep going
          if you tapped by accident.
        </Text>
        <View style={{ flexDirection: 'row', gap: 10, marginTop: 20 }}>
          <Pressable
            onPress={onCancel}
            style={{
              flex: 1, paddingVertical: 12, alignItems: 'center',
              backgroundColor: tokens.bgSubtle,
              borderWidth: 1, borderColor: tokens.border, borderRadius: 6,
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 2, color: tokens.text }}>
              KEEP LISTENING
            </Text>
          </Pressable>
          <Pressable
            onPress={onConfirm}
            style={{
              flex: 1, paddingVertical: 12, alignItems: 'center',
              backgroundColor: tokens.live, borderWidth: 1, borderColor: tokens.live, borderRadius: 6,
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 2, color: '#fff' }}>
              END · SAVE TO ARCHIVE
            </Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

function SavingOverlay() {
  const spin = useSharedValue(0);
  React.useEffect(() => {
    spin.value = withRepeat(withTiming(1, { duration: 1200, easing: Easing.linear }), -1, false);
  }, [spin]);
  const spinStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${spin.value * 360}deg` }],
  }));
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 48 }}>
      <Animated.View style={[{ width: 64, height: 64 }, spinStyle]}>
        <Svg width={64} height={64} viewBox="0 0 48 48" fill="none">
          <Circle cx={24} cy={24} r={20} stroke={tokens.borderSoft} strokeWidth={4} />
          <Path
            d="M24 4a20 20 0 0 1 20 20"
            stroke={tokens.live}
            strokeWidth={4}
            strokeLinecap="round"
          />
        </Svg>
      </Animated.View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.verified, fontWeight: '700', marginTop: 22 }}>
        SAVING TO ARCHIVE
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 18, fontWeight: '700', color: tokens.text, marginTop: 8, letterSpacing: -0.2 }}>
        Cleaning up points…
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted, marginTop: 6, lineHeight: 17, textAlign: 'center', maxWidth: 360 }}>
        Gemini is condensing your session into a post-match notes page. This takes a second.
      </Text>
    </View>
  );
}

// ── Idle landing: pre-match ready state ──
const CAPABILITIES = [
  { tag: 'STATS',     label: 'Stat whispers',      sub: 'xG · xA · career splits · head-to-heads — sourced from Sportradar' },
  { tag: 'STREAKS',   label: 'Streak alerts',      sub: 'Pre-computed; fires before the moment slips' },
  { tag: 'STORIES',   label: 'Storyline reminders', sub: 'Your pre-match prep, auto-ticked as you mention them' },
  { tag: 'TACTICS',   label: 'Tactical patterns',   sub: 'Formation shifts, pressing-map changes, set-piece tells' },
];

const READINESS = [
  { label: 'GEMMA 4 LOADED',     ok: true },
  { label: 'MATCH CACHE READY',  ok: true },
  { label: 'AIRPLANE MODE ON',   ok: true },
  { label: 'MIC AVAILABLE',      ok: true },
];

function StartUI({ onStart }: { onStart: () => void }) {
  const pulse = useSharedValue(0);
  React.useEffect(() => {
    pulse.value = withRepeat(
      withTiming(1, { duration: 1200, easing: Easing.inOut(Easing.quad) }),
      -1,
      true,
    );
  }, [pulse]);
  const ringStyle = useAnimatedStyle(() => ({
    opacity: interpolate(pulse.value, [0, 1], [0.6, 0]),
    transform: [{ scale: interpolate(pulse.value, [0, 1], [1, 1.35]) }],
  }));

  // Keyboard shortcut: SPACE starts the agent
  React.useEffect(() => {
    if (typeof window === 'undefined') return;
    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Space' && (e.target as HTMLElement)?.tagName !== 'INPUT') {
        e.preventDefault();
        onStart();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onStart]);

  return (
    <View style={{ flex: 1, paddingVertical: 36, paddingHorizontal: 48 }}>
      {/* Match context card — what the agent is tuned to */}
      <MatchContextCard />

      {/* Main body: capabilities left, start button right */}
      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 40, marginTop: 28 }}>
        {/* LEFT — capabilities */}
        <View style={{ flex: 1, gap: 10 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.textSubtle, fontWeight: '700' }}>
            WHAT YOU'LL GET
          </Text>
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 30,
              fontWeight: '700',
              color: tokens.text,
              letterSpacing: -0.6,
              lineHeight: 36,
              marginTop: 4,
            }}
          >
            A second-pair{'\n'}of broadcaster eyes.
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, lineHeight: 18, maxWidth: 460, marginTop: 4 }}>
            Under one second. On-device. Every surface sourced. Start it and switch freely — it follows in a floating window.
          </Text>
          <View style={{ marginTop: 18, gap: 8 }}>
            {CAPABILITIES.map((c) => (
              <View
                key={c.tag}
                style={{
                  flexDirection: 'row',
                  alignItems: 'flex-start',
                  gap: 12,
                  paddingVertical: 8,
                  paddingHorizontal: 12,
                  borderWidth: 1,
                  borderColor: tokens.borderSoft,
                  backgroundColor: tokens.bgRaised,
                  borderRadius: 6,
                }}
              >
                <View
                  style={{
                    paddingVertical: 2,
                    paddingHorizontal: 6,
                    borderRadius: 3,
                    borderWidth: 1,
                    borderColor: 'rgba(16,185,129,0.4)',
                    backgroundColor: 'rgba(16,185,129,0.08)',
                    marginTop: 2,
                  }}
                >
                  <Text
                    style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.4, color: tokens.verified }}
                  >
                    {c.tag}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '600', color: tokens.text, letterSpacing: 0.1 }}>
                    {c.label}
                  </Text>
                  <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, lineHeight: 14, marginTop: 2 }}>
                    {c.sub}
                  </Text>
                </View>
              </View>
            ))}
          </View>
        </View>

        {/* RIGHT — big start button */}
        <View style={{ flex: 1, alignItems: 'center', gap: 18 }}>
          <View style={{ width: 220, height: 220, alignItems: 'center', justifyContent: 'center' }}>
            <Animated.View
              style={[
                {
                  position: 'absolute',
                  width: 220,
                  height: 220,
                  borderRadius: 110,
                  backgroundColor: tokens.live,
                },
                ringStyle,
              ]}
            />
            <Pressable
              onPress={onStart}
              style={({ hovered }: any) => ({
                width: 190,
                height: 190,
                borderRadius: 95,
                backgroundColor: hovered ? '#f55a5a' : tokens.live,
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 18px 44px rgba(239,68,68,0.5)',
              })}
            >
              <Svg width={64} height={64} viewBox="0 0 24 24" fill="none">
                <Rect x={9} y={2} width={6} height={12} rx={3} stroke="#fff" strokeWidth={2} />
                <Path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" stroke="#fff" strokeWidth={2} strokeLinecap="round" />
              </Svg>
            </Pressable>
          </View>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 14,
            fontWeight: '700',
            letterSpacing: 3,
            color: tokens.text,
            marginTop: 22,
          }}
        >
          START LISTENING
        </Text>
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: 6,
            paddingVertical: 4,
            paddingHorizontal: 10,
            borderRadius: 4,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1,
            borderColor: tokens.borderSoft,
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, letterSpacing: 1.4 }}>
            OR PRESS
          </Text>
          <View
            style={{
              paddingVertical: 2,
              paddingHorizontal: 10,
              borderRadius: 3,
              backgroundColor: tokens.bgRaised,
              borderWidth: 1,
              borderColor: tokens.border,
            }}
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.4, color: tokens.text }}>
              SPACE
            </Text>
          </View>
        </View>
        </View>
      </View>

      {/* Readiness footer */}
      <View
        style={{
          flexDirection: 'row',
          gap: 22,
          marginTop: 18,
          paddingTop: 16,
          borderTopWidth: 1,
          borderTopColor: tokens.borderSoft,
          alignItems: 'center',
        }}
      >
        {READINESS.map((r) => (
          <View key={r.label} style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: r.ok ? tokens.verified : tokens.live }} />
            <Text
              style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.5, color: tokens.textMuted }}
            >
              {r.label}
            </Text>
          </View>
        ))}
        <View style={{ flex: 1 }} />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.4, color: tokens.textSubtle }}>
          ON-DEVICE · &lt;1S · GEMMA 4 ON CACTUS
        </Text>
      </View>
    </View>
  );
}

function MatchContextCard() {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 14,
        paddingHorizontal: 18,
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 8,
        gap: 18,
      }}
    >
      <View
        style={{
          paddingVertical: 3,
          paddingHorizontal: 8,
          borderRadius: 3,
          backgroundColor: 'rgba(16,185,129,0.08)',
          borderWidth: 1,
          borderColor: 'rgba(16,185,129,0.4)',
        }}
      >
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.6, color: tokens.verified }}>
          PRE-MATCH
        </Text>
      </View>
      <View style={{ flex: 1, flexDirection: 'row', alignItems: 'baseline', gap: 10 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 15, fontWeight: '700', color: tokens.text, letterSpacing: 0.2 }}>
          ARGENTINA vs FRANCE
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.4 }}>
          2022 WC FINAL · LUSAIL · DEC 18
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
        <Stat label="PLAYERS"     value="46" />
        <Divider />
        <Stat label="STORYLINES"  value="184" />
        <Divider />
        <Stat label="PRECEDENTS"  value="23" />
      </View>
    </View>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.6, color: tokens.textSubtle, fontWeight: '700' }}>
        {label}
      </Text>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 18,
          fontWeight: '700',
          color: tokens.text,
          letterSpacing: -0.2,
          marginTop: 2,
          fontVariant: ['tabular-nums'] as any,
        }}
      >
        {value}
      </Text>
    </View>
  );
}

function Divider() {
  return <View style={{ width: 1, height: 22, backgroundColor: tokens.borderSoft }} />;
}

// ── Active listening UI: scrolling point feed + STOP button ──
function ListeningUI({
  points,
  onStop,
}: {
  points: { id: string; text: string; source?: string; category?: string; at: number }[];
  onStop: () => void;
}) {
  return (
    <View style={{ flex: 1, padding: 32 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        <LiveDot />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.live, fontWeight: '700' }}>
          LIVE · AGENT IS LISTENING
        </Text>
        <View style={{ flex: 1 }} />
        <Pressable
          onPress={onStop}
          style={{
            paddingVertical: 8,
            paddingHorizontal: 14,
            borderRadius: 6,
            backgroundColor: tokens.bgRaised,
            borderWidth: 1,
            borderColor: tokens.border,
            flexDirection: 'row',
            alignItems: 'center',
            gap: 8,
          }}
        >
          <Svg width={10} height={10} viewBox="0 0 24 24" fill="none">
            <Rect x={6} y={6} width={12} height={12} rx={1.5} fill={tokens.textMuted} />
          </Svg>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.8, color: tokens.text }}>
            STOP
          </Text>
        </Pressable>
      </View>

      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 28,
          fontWeight: '700',
          color: tokens.text,
          marginTop: 12,
          letterSpacing: -0.56,
        }}
      >
        I'm on it.
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, marginTop: 6, lineHeight: 18 }}>
        Switch to another screen — I'll keep surfacing points in a floating window.
      </Text>

      <ScrollView
        style={{ flex: 1, marginTop: 24 }}
        contentContainerStyle={{ gap: 12, paddingBottom: 40 }}
        showsVerticalScrollIndicator={false}
      >
        {points.length === 0 && (
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textSubtle, fontStyle: 'italic' }}>
            Warming up the transcriber…
          </Text>
        )}
        {points.map((p, i) => (
          <Animated.View
            key={p.id}
            entering={FadeIn.duration(260)}
            exiting={FadeOut.duration(160)}
            layout={Layout.springify().damping(16)}
          >
            <PointCard point={p} prominent={i === 0} />
          </Animated.View>
        ))}
      </ScrollView>
    </View>
  );
}

function PointCard({
  point,
  prominent,
}: {
  point: { id: string; text: string; source?: string; category?: string; at: number };
  prominent: boolean;
}) {
  return (
    <View
      style={{
        padding: 16,
        backgroundColor: prominent ? tokens.bgRaised : tokens.bgSubtle,
        borderLeftWidth: 3,
        borderLeftColor: prominent ? tokens.live : tokens.border,
        borderWidth: 1,
        borderColor: tokens.borderSoft,
        borderRadius: 6,
      }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 9,
            fontWeight: '700',
            letterSpacing: 1.8,
            color: prominent ? tokens.live : tokens.textSubtle,
          }}
        >
          ● {point.category?.toUpperCase() ?? 'NOTE'}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>
          · {timeAgo(point.at)}
        </Text>
      </View>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: prominent ? 15 : 13,
          color: tokens.text,
          lineHeight: prominent ? 20 : 17,
          fontWeight: prominent ? '500' : '400',
        }}
      >
        {point.text}
      </Text>
      {point.source && (
        <Text
          style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.verified, letterSpacing: 1.3, marginTop: 8 }}
        >
          ✓ {point.source}
        </Text>
      )}
    </View>
  );
}

function LiveDot() {
  const p = useSharedValue(0);
  React.useEffect(() => {
    p.value = withRepeat(withTiming(1, { duration: 700, easing: Easing.inOut(Easing.quad) }), -1, true);
  }, [p]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(p.value, [0, 1], [0.4, 1]),
  }));
  return (
    <Animated.View style={[{ width: 10, height: 10, borderRadius: 5, backgroundColor: tokens.live }, style]} />
  );
}

function timeAgo(ts: number): string {
  const d = Math.max(0, Math.floor((Date.now() - ts) / 1000));
  if (d < 5) return 'now';
  if (d < 60) return `${d}s ago`;
  return `${Math.floor(d / 60)}m ago`;
}
