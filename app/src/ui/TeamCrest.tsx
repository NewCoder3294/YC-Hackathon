import React from 'react';
import { Text, View } from 'react-native';
import Svg, { Circle, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { TeamBrand, isLightPrimary } from '../theme/teams';

// ────────────────────────────────────────────────────────────────────────────
// FlagSVG — renders a national flag from a pattern description. Falls back to
// a 2-color split (primary | secondary) when the team has no flag or uses a
// pattern we don't render procedurally (e.g. clubs, complex emblems).
// ────────────────────────────────────────────────────────────────────────────

type FlagProps = { team: TeamBrand; width?: number; rounded?: boolean };

export function FlagSVG({ team, width = 22, rounded = true }: FlagProps) {
  const height = Math.round(width * (2 / 3)); // standard 3:2 flag aspect
  const rx = rounded ? 2 : 0;
  const strokeColor = tokens.borderSoft;
  const flag = team.flag;

  const frame = (content: React.ReactNode) => (
    <Svg width={width} height={height} viewBox={`0 0 30 20`}>
      {content}
      <Rect x={0.5} y={0.5} width={29} height={19} rx={rx} ry={rx} fill="none" stroke={strokeColor} strokeWidth={1} />
    </Svg>
  );

  if (!flag) {
    return frame(
      <>
        <Rect width={20} height={20} fill={team.primary} rx={rx} ry={rx} />
        <Rect x={20} width={10} height={20} fill={team.secondary} />
      </>,
    );
  }

  switch (flag.kind) {
    case 'hs3':
      return frame(
        <>
          <Rect width={30} height={20 / 3} fill={flag.colors[0]} />
          <Rect y={20 / 3} width={30} height={20 / 3} fill={flag.colors[1]} />
          <Rect y={(40 / 3)} width={30} height={20 / 3} fill={flag.colors[2]} />
        </>,
      );
    case 'vs3':
      return frame(
        <>
          <Rect width={10} height={20} fill={flag.colors[0]} />
          <Rect x={10} width={10} height={20} fill={flag.colors[1]} />
          <Rect x={20} width={10} height={20} fill={flag.colors[2]} />
        </>,
      );
    case 'hs2':
      return frame(
        <>
          <Rect width={30} height={10} fill={flag.colors[0]} />
          <Rect y={10} width={30} height={10} fill={flag.colors[1]} />
        </>,
      );
    case 'vs2':
      return frame(
        <>
          <Rect width={15} height={20} fill={flag.colors[0]} />
          <Rect x={15} width={15} height={20} fill={flag.colors[1]} />
        </>,
      );
    case 'nordic':
      return frame(
        <>
          <Rect width={30} height={20} fill={flag.bg} />
          {/* horizontal cross bar */}
          <Rect y={8} width={30} height={4} fill={flag.cross} />
          {/* vertical cross bar (off-center, Nordic convention) */}
          <Rect x={10} width={4} height={20} fill={flag.cross} />
        </>,
      );
    case 'disc':
      return frame(
        <>
          <Rect width={30} height={20} fill={flag.bg} />
          <Circle cx={15} cy={10} r={5} fill={flag.disc} />
        </>,
      );
    case 'canton':
      return frame(
        <>
          <Rect width={30} height={20} fill={flag.base} />
          <Rect width={12} height={8} fill={flag.canton} />
        </>,
      );
    case 'solid':
      return frame(<Rect width={30} height={20} fill={flag.color} />);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TeamChip — abbreviation on team primary color. Used for club/MLB/MLS where
// we don't draw a flag.
// ────────────────────────────────────────────────────────────────────────────

export function TeamChip({ team, height = 22 }: { team: TeamBrand; height?: number }) {
  const width = Math.round(height * 1.5);
  const textColor = isLightPrimary(team) ? '#0A0A0A' : '#FAFAFA';
  return (
    <View
      style={{
        width,
        height,
        backgroundColor: team.primary,
        borderWidth: 1,
        borderColor: team.secondary,
        borderRadius: 3,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Text style={{ fontFamily: FONT_MONO, fontSize: Math.round(height * 0.45), fontWeight: '700', letterSpacing: 1, color: textColor }}>
        {team.abbr}
      </Text>
    </View>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// TeamCrest — high-level: renders a flag for international teams, chip for
// the rest. Size controls visual height.
// ────────────────────────────────────────────────────────────────────────────

export function TeamCrest({ team, size = 22 }: { team: TeamBrand; size?: number }) {
  if (team.league === 'intl') {
    return <FlagSVG team={team} width={Math.round(size * 1.35)} />;
  }
  return <TeamChip team={team} height={size} />;
}
