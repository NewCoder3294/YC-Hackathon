import React from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, View } from 'react-native';
import Animated, { FadeInDown, Layout } from 'react-native-reanimated';
import Svg, { Circle, G, Line, Rect, Text as SvgText } from 'react-native-svg';
import { IPadFrame } from '../frame/IPadFrame';
import { FONT_MONO, tokens } from '../theme/tokens';
import {
  FormationSection,
  KeyEvent,
  MatchSummary,
  PossessionSection,
  PressingSection,
  ShiftsSection,
  TacticsBundle,
  XGSection,
} from '../sports/types';
import { soccerAdapter } from '../sports/soccer/adapter';

// TacticsScreen — soccer only, backed by StatsBomb Open Data.
// Every number on screen is aggregated from real match events.
export function TacticsScreen() {
  const [matches, setMatches] = React.useState<MatchSummary[]>([]);
  const [selectedId, setSelectedId] = React.useState<string | null>(null);
  const [bundle, setBundle] = React.useState<TacticsBundle | null>(null);
  const [listLoading, setListLoading] = React.useState(false);
  const [matchLoading, setMatchLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const loadList = React.useCallback(async () => {
    setListLoading(true);
    setError(null);
    try {
      const list = await soccerAdapter.listMatches();
      setMatches(list);
      if (list[0]) setSelectedId(list[0].id);
    } catch (e) {
      setError(`Could not load matches: ${(e as Error).message}`);
    } finally {
      setListLoading(false);
    }
  }, []);

  const loadMatch = React.useCallback(async (id: string) => {
    setMatchLoading(true);
    setError(null);
    setBundle(null);
    try {
      const b = await soccerAdapter.loadMatch(id);
      setBundle(b);
    } catch (e) {
      setError(`Could not load match: ${(e as Error).message}`);
    } finally {
      setMatchLoading(false);
    }
  }, []);

  React.useEffect(() => { loadList(); }, [loadList]);
  React.useEffect(() => {
    if (selectedId) loadMatch(selectedId);
  }, [selectedId, loadMatch]);

  return (
    <IPadFrame hidePattern>
      <View style={{ flex: 1, flexDirection: 'row' }}>
        <View style={{ width: 300, borderRightWidth: 1, borderRightColor: tokens.border }}>
          <View style={{ padding: 18, borderBottomWidth: 1, borderBottomColor: tokens.borderSoft, backgroundColor: tokens.bgRaised }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.2, color: tokens.textSubtle, fontWeight: '700' }}>
              TACTICS · SOCCER
            </Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 18, fontWeight: '700', color: tokens.text, marginTop: 6, letterSpacing: -0.2 }}>
              Pick a match
            </Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.3, color: tokens.textSubtle, marginTop: 10, lineHeight: 13 }}>
              DATA · STATSBOMB OPEN{'\n'}
              Every stat below aggregated from the full event feed.
            </Text>
          </View>
          <ScrollView contentContainerStyle={{ padding: 12, gap: 8 }} showsVerticalScrollIndicator={false}>
            {listLoading && <LoadingRow label="Loading matches…" />}
            {!listLoading && matches.length === 0 && !error && (
              <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textSubtle, padding: 10 }}>
                No matches available.
              </Text>
            )}
            {matches.map((m) => (
              <MatchRow key={m.id} match={m} active={m.id === selectedId} onPress={() => setSelectedId(m.id)} />
            ))}
          </ScrollView>
        </View>

        <View style={{ flex: 1 }}>
          {matchLoading && <CenterLoader label="Fetching events + lineups…" />}
          {error && !matchLoading && <CenterError message={error} />}
          {!matchLoading && !error && !bundle && <CenterPlaceholder />}
          {!matchLoading && bundle && <BundleView bundle={bundle} />}
        </View>
      </View>
    </IPadFrame>
  );
}

function MatchRow({ match, active, onPress }: { match: MatchSummary; active: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ hovered }: any) => ({
        paddingVertical: 10,
        paddingHorizontal: 12,
        borderRadius: 6,
        backgroundColor: active ? tokens.bgSubtle : hovered ? tokens.bgHover : 'transparent',
        borderLeftWidth: 2,
        borderLeftColor: active ? tokens.live : 'transparent',
      })}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.text, fontWeight: '700', letterSpacing: 0.2 }}>
        {match.label}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, marginTop: 4, letterSpacing: 1.1 }}>
        {match.sublabel}
      </Text>
    </Pressable>
  );
}

function BundleView({ bundle }: { bundle: TacticsBundle }) {
  return (
    <ScrollView
      style={{ flex: 1 }}
      contentContainerStyle={{ paddingVertical: 24, paddingHorizontal: 32, gap: 20 }}
      showsVerticalScrollIndicator={false}
    >
      <BundleHeader bundle={bundle} />
      <FormationBlock section={bundle.formation} />
      <View style={{ flexDirection: 'row', gap: 16 }}>
        <View style={{ flex: 1 }}><PressingBlock section={bundle.pressing} /></View>
        <View style={{ flex: 1 }}><XGBlock section={bundle.xg} /></View>
      </View>
      <PossessionBlock section={bundle.possession} />
      <ShiftsBlock section={bundle.shifts} />
      {bundle.keyEvents.length > 0 && <KeyEventsBlock events={bundle.keyEvents} home={bundle.home.code} away={bundle.away.code} />}
      <SourceFooter matchId={bundle.match.id} />
    </ScrollView>
  );
}

function BundleHeader({ bundle }: { bundle: TacticsBundle }) {
  return (
    <Animated.View entering={FadeInDown.duration(220)}>
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
        <View style={{ flex: 1 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 15, fontWeight: '700', color: tokens.text, letterSpacing: 0.2 }}>
            {bundle.match.label}
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.3, marginTop: 2 }}>
            {bundle.match.sublabel}
          </Text>
        </View>
        {bundle.topStats.map((s, i) => (
          <React.Fragment key={s.label}>
            <View>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.6, color: tokens.textSubtle, fontWeight: '700' }}>
                {s.label}
              </Text>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 13, fontWeight: '700', color: tokens.text, marginTop: 2, letterSpacing: 0.2 }}>
                {s.value}
              </Text>
            </View>
            {i < bundle.topStats.length - 1 && <View style={{ width: 1, height: 24, backgroundColor: tokens.borderSoft }} />}
          </React.Fragment>
        ))}
      </View>
    </Animated.View>
  );
}

// ── Formation face-off ──
function FormationBlock({ section }: { section: FormationSection }) {
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(40)} layout={Layout.springify()}>
      <SectionTitle eyebrow="FORMATION FACE-OFF" title="Shape from the starting XI event" />
      <View style={{ flexDirection: 'row', gap: 16, marginTop: 14 }}>
        {[section.home, section.away].map((f) => (
          <View
            key={f.team.id}
            style={{
              flex: 1,
              backgroundColor: tokens.bgRaised,
              borderWidth: 1,
              borderColor: tokens.border,
              borderRadius: 8,
              overflow: 'hidden',
            }}
          >
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                paddingVertical: 12,
                paddingHorizontal: 14,
                borderBottomWidth: 1,
                borderBottomColor: tokens.borderSoft,
                backgroundColor: tokens.bgSubtle,
                gap: 10,
              }}
            >
              <View style={{ width: 8, height: 28, borderRadius: 2, backgroundColor: f.team.color }} />
              <View style={{ flex: 1 }}>
                <Text style={{ fontFamily: FONT_MONO, fontSize: 13, fontWeight: '700', color: tokens.text, letterSpacing: 0.3 }}>
                  {f.team.name.toUpperCase()}
                </Text>
                <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.3, color: tokens.textSubtle, marginTop: 2 }}>
                  {f.starters.length} STARTERS
                </Text>
              </View>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 22, fontWeight: '700', color: tokens.text, letterSpacing: 0.5 }}>
                {f.formation}
              </Text>
            </View>
            <PitchSvg starters={f.starters} accent={f.team.color} />
          </View>
        ))}
      </View>
      <Takeaway text={section.takeaway} />
    </Animated.View>
  );
}

function PitchSvg({ starters, accent }: { starters: FormationSection['home']['starters']; accent: string }) {
  return (
    <View style={{ paddingVertical: 14, paddingHorizontal: 14, alignItems: 'center' }}>
      <Svg width={300} height={240} viewBox="0 0 100 100">
        <Rect x={2} y={2} width={96} height={96} rx={3} fill={tokens.bgBase} stroke={tokens.borderSoft} strokeWidth={0.4} />
        <Line x1={2} y1={50} x2={98} y2={50} stroke={tokens.borderSoft} strokeWidth={0.3} />
        <Circle cx={50} cy={50} r={8} stroke={tokens.borderSoft} strokeWidth={0.3} fill="none" />
        <Rect x={30} y={2} width={40} height={14} stroke={tokens.borderSoft} strokeWidth={0.3} fill="none" />
        <Rect x={30} y={84} width={40} height={14} stroke={tokens.borderSoft} strokeWidth={0.3} fill="none" />
        {starters.map((p) => (
          <G key={p.id}>
            <Circle cx={p.x} cy={p.y} r={3.6} fill={accent} opacity={0.9} />
            <SvgText
              x={p.x}
              y={p.y + 1.2}
              textAnchor="middle"
              fontSize={3.2}
              fontWeight="700"
              fill="#0A0A0A"
              fontFamily={FONT_MONO}
            >
              {p.shirt}
            </SvgText>
          </G>
        ))}
      </Svg>
    </View>
  );
}

// ── Pressing ──
function PressingBlock({ section }: { section: PressingSection }) {
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(80)}>
      <SectionTitle eyebrow="PRESSING" title="PPDA + defensive thirds" />
      <View
        style={{
          marginTop: 14,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 8,
          padding: 16,
          gap: 16,
        }}
      >
        {[section.home, section.away].map((b) => {
          const total = b.defHigh + b.defMid + b.defLow || 1;
          return (
            <View key={b.team.id}>
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 6 }}>
                <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 1.5, color: tokens.text }}>
                  {b.team.code}
                </Text>
                <View style={{ flex: 1 }} />
                <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.2, color: tokens.textSubtle }}>
                  PPDA · {b.ppda.toFixed(1)} · PRESS {b.pressuresHigh}H/{b.pressuresMid}M
                </Text>
              </View>
              <View style={{ flexDirection: 'row', height: 10, borderRadius: 2, overflow: 'hidden', backgroundColor: tokens.bgSubtle }}>
                <View style={{ flex: b.defHigh / total || 0.001, backgroundColor: '#EF4444' }} />
                <View style={{ flex: b.defMid / total || 0.001, backgroundColor: '#F59E0B' }} />
                <View style={{ flex: b.defLow / total || 0.001, backgroundColor: '#6B7280' }} />
              </View>
              <View style={{ flexDirection: 'row', gap: 14, marginTop: 6 }}>
                <MiniLegend color="#EF4444" label="HIGH" count={b.defHigh} />
                <MiniLegend color="#F59E0B" label="MID" count={b.defMid} />
                <MiniLegend color="#6B7280" label="LOW" count={b.defLow} />
              </View>
            </View>
          );
        })}
        <Takeaway text={section.takeaway} inline />
      </View>
    </Animated.View>
  );
}

function MiniLegend({ color, label, count }: { color: string; label: string; count: number }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
      <View style={{ width: 6, height: 6, borderRadius: 1, backgroundColor: color }} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.1, color: tokens.textMuted, fontWeight: '700' }}>{label}</Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text }}>{count}</Text>
    </View>
  );
}

// ── xG ──
function XGBlock({ section }: { section: XGSection }) {
  const max = Math.max(section.home.xgTotal, section.away.xgTotal, 0.1);
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(120)}>
      <SectionTitle eyebrow="xG · FROM REAL SHOTS" title="Open play vs set piece" />
      <View
        style={{
          marginTop: 14,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 8,
          padding: 16,
          gap: 14,
        }}
      >
        {[section.home, section.away].map((t) => {
          const pct = Math.max(0.02, t.xgTotal / max);
          const openPct = t.xgTotal > 0 ? t.xgOpenPlay / t.xgTotal : 0;
          return (
            <View key={t.team.id}>
              <View style={{ flexDirection: 'row', alignItems: 'baseline', marginBottom: 4 }}>
                <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', color: tokens.text, letterSpacing: 1.5 }}>
                  {t.team.code}
                </Text>
                <View style={{ flex: 1 }} />
                <Text style={{ fontFamily: FONT_MONO, fontSize: 16, fontWeight: '700', color: tokens.text }}>
                  {t.xgTotal.toFixed(2)}
                </Text>
              </View>
              <View style={{ height: 10, borderRadius: 2, backgroundColor: tokens.bgSubtle, overflow: 'hidden', flexDirection: 'row' }}>
                <View style={{ width: `${pct * openPct * 100}%`, height: '100%', backgroundColor: t.team.color }} />
                <View style={{ width: `${pct * (1 - openPct) * 100}%`, height: '100%', backgroundColor: t.team.color, opacity: 0.45 }} />
              </View>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.1, color: tokens.textSubtle, marginTop: 4 }}>
                OPEN {t.xgOpenPlay.toFixed(2)} · SET {t.xgSetPiece.toFixed(2)} · {t.shots} SHOTS · {t.shotsOnTarget} ON TARGET
              </Text>
              {t.topShooter && (
                <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.1, color: tokens.textMuted, marginTop: 2 }}>
                  TOP · {t.topShooter.name.toUpperCase()} · {t.topShooter.xg.toFixed(2)} xG from {t.topShooter.shots}
                </Text>
              )}
            </View>
          );
        })}
        <Takeaway text={section.takeaway} inline />
      </View>
    </Animated.View>
  );
}

// ── Possession ──
function PossessionBlock({ section }: { section: PossessionSection }) {
  const total = section.home.passes + section.away.passes || 1;
  const hPct = section.home.passes / total;
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(160)}>
      <SectionTitle eyebrow="POSSESSION · PASSING" title="Who had the ball, and how far forward" />
      <View
        style={{
          marginTop: 14,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 8,
          padding: 16,
          gap: 12,
        }}
      >
        <View style={{ flexDirection: 'row', height: 14, borderRadius: 2, overflow: 'hidden', backgroundColor: tokens.bgSubtle }}>
          <View style={{ flex: hPct, backgroundColor: section.home.team.color }} />
          <View style={{ flex: 1 - hPct, backgroundColor: section.away.team.color }} />
        </View>
        <View style={{ flexDirection: 'row' }}>
          <PossessionSide stats={section.home} />
          <View style={{ width: 1, backgroundColor: tokens.borderSoft, marginHorizontal: 14 }} />
          <PossessionSide stats={section.away} />
        </View>
        <Takeaway text={section.takeaway} inline />
      </View>
    </Animated.View>
  );
}

function PossessionSide({ stats }: { stats: PossessionSection['home'] }) {
  return (
    <View style={{ flex: 1, gap: 4 }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', letterSpacing: 1.5, color: tokens.text }}>
        {stats.team.code}
      </Text>
      <View style={{ flexDirection: 'row', gap: 16, marginTop: 4 }}>
        <StatCell label="PASSES" value={String(stats.passes)} />
        <StatCell label="COMPLETE" value={`${Math.round(stats.passAccuracy * 100)}%`} />
        <StatCell label="SHARE" value={`${Math.round(stats.possessionShare * 100)}%`} />
        <StatCell label="PROGRESSIVE" value={String(stats.progressivePasses)} />
      </View>
    </View>
  );
}

function StatCell({ label, value }: { label: string; value: string }) {
  return (
    <View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.4, color: tokens.textSubtle, fontWeight: '700' }}>
        {label}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 13, fontWeight: '700', color: tokens.text, marginTop: 2 }}>
        {value}
      </Text>
    </View>
  );
}

// ── Tactical shifts ──
function ShiftsBlock({ section }: { section: ShiftsSection }) {
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(200)}>
      <SectionTitle eyebrow="TACTICAL SHIFTS" title="Formation changes, real event log" />
      <View
        style={{
          marginTop: 14,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 8,
          padding: 16,
          gap: 10,
        }}
      >
        {section.events.length === 0 ? (
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textSubtle, fontStyle: 'italic' }}>
            {section.takeaway}
          </Text>
        ) : (
          section.events.map((s, i) => (
            <View
              key={i}
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                gap: 12,
                paddingVertical: 8,
                borderTopWidth: i === 0 ? 0 : 1,
                borderTopColor: tokens.borderSoft,
              }}
            >
              <View
                style={{
                  paddingVertical: 3,
                  paddingHorizontal: 8,
                  borderRadius: 3,
                  backgroundColor: tokens.bgSubtle,
                  borderWidth: 1,
                  borderColor: tokens.borderSoft,
                  minWidth: 50,
                  alignItems: 'center',
                }}
              >
                <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.2, color: tokens.text }}>
                  {s.minute}'
                </Text>
              </View>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 11, fontWeight: '700', color: tokens.text, letterSpacing: 1.2 }}>
                {s.teamCode}
              </Text>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted }}>
                {s.from ? `${s.from} → ${s.to}` : s.to}
              </Text>
            </View>
          ))
        )}
      </View>
    </Animated.View>
  );
}

// ── Key events ──
function KeyEventsBlock({ events, home, away }: { events: KeyEvent[]; home: string; away: string }) {
  return (
    <Animated.View entering={FadeInDown.duration(240).delay(240)}>
      <SectionTitle eyebrow="KEY EVENTS" title="Goals + cards from the event feed" />
      <View
        style={{
          marginTop: 14,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 8,
          overflow: 'hidden',
        }}
      >
        {events.map((e, i) => (
          <View
            key={i}
            style={{
              flexDirection: 'row',
              gap: 14,
              paddingVertical: 12,
              paddingHorizontal: 16,
              borderTopWidth: i === 0 ? 0 : 1,
              borderTopColor: tokens.borderSoft,
              alignItems: 'flex-start',
            }}
          >
            <View
              style={{
                paddingHorizontal: 6,
                paddingVertical: 2,
                borderRadius: 2,
                borderWidth: 1,
                borderColor: tokens.borderSoft,
                backgroundColor: tokens.bgSubtle,
                marginTop: 2,
              }}
            >
              <Text style={{ fontFamily: FONT_MONO, fontSize: 8, fontWeight: '700', letterSpacing: 1.4, color: e.kind === 'RED' ? tokens.live : tokens.textMuted }}>
                {e.teamCode} · {e.kind}
              </Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', color: tokens.text, letterSpacing: 0.2 }}>
                {e.headline}
              </Text>
              <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, lineHeight: 15, marginTop: 4 }}>
                {e.detail}
              </Text>
            </View>
          </View>
        ))}
      </View>
    </Animated.View>
  );
}

// ── Source footer — keeps honesty visible ──
function SourceFooter({ matchId }: { matchId: string }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        paddingTop: 14,
        borderTopWidth: 1,
        borderTopColor: tokens.borderSoft,
      }}
    >
      <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: tokens.verified }} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.3, color: tokens.textSubtle }}>
        SOURCE · STATSBOMB OPEN DATA · match_id={matchId}
      </Text>
    </View>
  );
}

// ── Utility atoms ──
function SectionTitle({ eyebrow, title }: { eyebrow: string; title: string }) {
  return (
    <View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2, color: tokens.textSubtle, fontWeight: '700' }}>
        {eyebrow}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 20, fontWeight: '700', color: tokens.text, letterSpacing: -0.3, marginTop: 4 }}>
        {title}
      </Text>
    </View>
  );
}

function Takeaway({ text, inline = false }: { text: string; inline?: boolean }) {
  return (
    <Text
      style={{
        fontFamily: FONT_MONO,
        fontSize: 10,
        color: tokens.textSubtle,
        lineHeight: 15,
        marginTop: inline ? 4 : 10,
      }}
    >
      {text}
    </Text>
  );
}

function LoadingRow({ label }: { label: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, padding: 10 }}>
      <ActivityIndicator size="small" color={tokens.textSubtle} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.1 }}>
        {label}
      </Text>
    </View>
  );
}

function CenterLoader({ label }: { label: string }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 }}>
      <ActivityIndicator size="large" color={tokens.textMuted} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 1.6, color: tokens.textSubtle, fontWeight: '700' }}>
        {label.toUpperCase()}
      </Text>
    </View>
  );
}

function CenterError({ message }: { message: string }) {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10, padding: 32 }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 1.8, color: tokens.live, fontWeight: '700' }}>
        DATA SOURCE ERROR
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, lineHeight: 18, textAlign: 'center', maxWidth: 420 }}>
        {message}
      </Text>
    </View>
  );
}

function CenterPlaceholder() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 8 }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 1.8, color: tokens.textSubtle, fontWeight: '700' }}>
        NOTHING SELECTED
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted }}>
        Pick a match from the list.
      </Text>
    </View>
  );
}
