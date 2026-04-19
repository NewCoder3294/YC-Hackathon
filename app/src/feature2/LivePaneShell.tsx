import React from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { getTeam } from '../theme/teams';
import { FlagSVG } from '../ui/TeamCrest';
import { ListeningDot, LatencyTag, Waveform } from './atoms';

type Props = {
  clock: string;
  score: { arg: number; fra: number };
  phase: string;
  phaseColor?: string;
  listening: boolean;
  latency?: string;
  onVoicePress?: () => void;
  onVoiceRelease?: () => void;
  rightSlot?: React.ReactNode;
  children: React.ReactNode;
  hideBottomBezel?: boolean;
};

// Match-level shell: top bar (score · clock · phase · listening dot), body,
// and optionally a full-width bottom voice bezel. Pass `hideBottomBezel` when
// the caller places its own <VoiceBezel> inside a column (e.g. Feature 2
// anchors the mic to the whisper-agent pane instead).
export function LivePaneShell({
  clock,
  score,
  phase,
  phaseColor,
  listening,
  latency = '842ms',
  onVoicePress,
  onVoiceRelease,
  rightSlot,
  children,
  hideBottomBezel = false,
}: Props) {
  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase }}>
      {/* Top bar — column split mirrors the body: 55% lineup zone | 45% whisper zone.
          Scoreboard centers within the lineup zone so it sits between the ARG and FRA
          team cards below. Listening + sim controls live in the whisper zone. */}
      <View
        style={{
          borderBottomWidth: 1,
          borderBottomColor: tokens.borderSoft,
          backgroundColor: tokens.bgRaised,
          flexDirection: 'row',
          alignItems: 'stretch',
        }}
      >
        {/* LINEUP ZONE — scoreboard centered. Explicit 55% width matches the
            body column split so the divider aligns exactly with the body. */}
        <View
          style={{
            width: '55%',
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            paddingVertical: 12,
            paddingHorizontal: 20,
            borderRightWidth: 1,
            borderRightColor: tokens.borderSoft,
          }}
        >
          <Scoreboard score={score} clock={clock} phase={phase} phaseColor={phaseColor} />
        </View>

        {/* WHISPER ZONE — listening + controls. Matches body's 45% pane. */}
        <View
          style={{
            width: '45%',
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'space-between',
            paddingVertical: 12,
            paddingHorizontal: 20,
            gap: 12,
            overflow: 'hidden',
          }}
        >
          <ListeningDot />
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>{rightSlot}</View>
        </View>
      </View>

      {/* Body */}
      <View style={{ flex: 1, paddingVertical: 14, paddingHorizontal: 20, gap: 14 }}>{children}</View>

      {/* Bottom bezel (optional) */}
      {!hideBottomBezel && (
        <VoiceBezel
          listening={listening}
          latency={latency}
          onPress={onVoicePress}
          onRelease={onVoiceRelease}
        />
      )}
    </View>
  );
}

// Standalone bezel — same visual as the shell's bottom bar, exported so a
// screen can anchor the press-to-talk control inside a specific column.
export function VoiceBezel({
  listening,
  latency = '842ms',
  onPress,
  onRelease,
}: {
  listening: boolean;
  latency?: string;
  onPress?: () => void;
  onRelease?: () => void;
}) {
  return (
    <View
      style={{
        borderTopWidth: 1,
        borderTopColor: tokens.borderSoft,
        backgroundColor: tokens.bgRaised,
        paddingVertical: 14,
        paddingHorizontal: 20,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
      }}
    >
      <Pressable
        onPressIn={onPress}
        onPressOut={onRelease}
        style={{
          flex: 1,
          flexDirection: 'row',
          alignItems: 'center',
          gap: 10,
          paddingVertical: 12,
          paddingHorizontal: 16,
          backgroundColor: listening ? 'rgba(239,68,68,0.08)' : tokens.bgSubtle,
          borderWidth: 1,
          borderColor: listening ? tokens.live : tokens.border,
          borderRadius: 10,
        }}
      >
        <Svg viewBox="0 0 24 24" width={18} height={18} fill="none">
          <Rect x={9} y={2} width={6} height={12} rx={3} stroke={listening ? tokens.live : tokens.text} strokeWidth={1.75} />
          <Path
            d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8"
            stroke={listening ? tokens.live : tokens.text}
            strokeWidth={1.75}
            strokeLinecap="round"
          />
        </Svg>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 11,
            fontWeight: '700',
            letterSpacing: 1.8,
            color: listening ? tokens.live : tokens.text,
          }}
        >
          {listening ? 'LISTENING…' : 'HOLD TO ASK'}
        </Text>
        {listening && <Waveform color={tokens.live} />}
      </Pressable>
      <LatencyTag ms={latency} />
    </View>
  );
}

// Unified scoreboard pill: ARG | score | FRA, with clock and phase chip as
// trailing meta. Single element so it centers cleanly in the lineup zone.
function Scoreboard({
  score, clock, phase, phaseColor,
}: {
  score: { arg: number; fra: number };
  clock: string;
  phase: string;
  phaseColor?: string;
}) {
  const home = getTeam('ARG');
  const away = getTeam('FRA');
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: 14,
          paddingVertical: 8,
          paddingHorizontal: 18,
          backgroundColor: tokens.bgSubtle,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 12,
        }}
      >
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <FlagSVG team={home} width={22} />
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 13,
              fontWeight: '700',
              letterSpacing: 2.6,
              color: home.primary,
            }}
          >
            {home.abbr}
          </Text>
        </View>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 44,
            fontWeight: '700',
            color: tokens.text,
            letterSpacing: -1.4,
            lineHeight: 46,
            fontVariant: ['tabular-nums'] as any,
            minWidth: 32,
            textAlign: 'center',
          }}
        >
          {score.arg}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 24, color: tokens.textSubtle, marginTop: -4 }}>–</Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 44,
            fontWeight: '700',
            color: tokens.text,
            letterSpacing: -1.4,
            lineHeight: 46,
            fontVariant: ['tabular-nums'] as any,
            minWidth: 32,
            textAlign: 'center',
          }}
        >
          {score.fra}
        </Text>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 13,
              fontWeight: '700',
              letterSpacing: 2.6,
              color: away.primary,
            }}
          >
            {away.abbr}
          </Text>
          <FlagSVG team={away} width={22} />
        </View>
      </View>

      <View style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 4 }}>
        <View
          style={{
            paddingVertical: 4,
            paddingHorizontal: 8,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1,
            borderColor: tokens.borderSoft,
            borderRadius: 4,
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', letterSpacing: 1.4, color: tokens.textMuted, fontVariant: ['tabular-nums'] as any }}>
            {clock}
          </Text>
        </View>
        {phase ? (
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: 5,
              paddingVertical: 3,
              paddingHorizontal: 7,
              borderWidth: 1,
              borderColor: phaseColor ? `${phaseColor}70` : tokens.borderSoft,
              backgroundColor: phaseColor ? `${phaseColor}15` : tokens.bgSubtle,
              borderRadius: 3,
            }}
          >
            {phase === 'LIVE' && (
              <View style={{ width: 5, height: 5, borderRadius: 2.5, backgroundColor: phaseColor ?? tokens.live }} />
            )}
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 9,
                letterSpacing: 1.6,
                fontWeight: '700',
                color: phaseColor ?? tokens.textMuted,
              }}
            >
              {phase}
            </Text>
          </View>
        ) : null}
      </View>
    </View>
  );
}
