import React from 'react';
import Svg, { Circle, Line, Rect } from 'react-native-svg';
import { tokens } from '../theme/tokens';

type Dot = { x: number; y: number; r?: string; hl?: boolean };

const POSITIONS: Record<string, Dot[]> = {
  '4-3-3': [
    { x:  8, y: 50, r: 'GK' },
    { x: 22, y: 15 }, { x: 22, y: 38 }, { x: 22, y: 62 }, { x: 22, y: 85 },
    { x: 48, y: 30 }, { x: 48, y: 50 }, { x: 48, y: 70 },
    { x: 76, y: 20 }, { x: 82, y: 50, hl: true }, { x: 76, y: 80 },
  ],
  '4-2-3-1': [
    { x:  8, y: 50, r: 'GK' },
    { x: 22, y: 15 }, { x: 22, y: 38 }, { x: 22, y: 62 }, { x: 22, y: 85 },
    { x: 40, y: 35 }, { x: 40, y: 65 },
    { x: 60, y: 22 }, { x: 60, y: 50 }, { x: 60, y: 78 },
    { x: 86, y: 50, hl: true },
  ],
};

export function MiniPitch({ formation = '4-3-3', nation = 'ARG' }: { formation?: string; nation?: 'ARG' | 'FRA' }) {
  const dots = POSITIONS[formation] ?? POSITIONS['4-3-3'];
  const accent = nation === 'ARG' ? tokens.text : tokens.textMuted;
  return (
    <Svg viewBox="0 0 140 80" width={140} height={80}>
      <Rect x={2} y={2} width={136} height={76} rx={2} fill="#0e1c12" stroke={tokens.border} strokeWidth={0.5} />
      <Line x1={70} y1={2} x2={70} y2={78} stroke={tokens.border} strokeWidth={0.5} />
      <Circle cx={70} cy={40} r={9} fill="none" stroke={tokens.border} strokeWidth={0.5} />
      <Rect x={2}  y={22} width={14} height={36} fill="none" stroke={tokens.border} strokeWidth={0.5} />
      <Rect x={124} y={22} width={14} height={36} fill="none" stroke={tokens.border} strokeWidth={0.5} />
      {dots.map((d, i) => {
        const cy = d.y * 0.8 + 2;
        const color = d.hl ? tokens.live : accent;
        return (
          <React.Fragment key={i}>
            <Circle cx={d.x} cy={cy} r={2.4} fill={color} />
            {d.hl && <Circle cx={d.x} cy={cy} r={4.5} fill="none" stroke={tokens.live} strokeWidth={0.5} strokeOpacity={0.5} />}
          </React.Fragment>
        );
      })}
    </Svg>
  );
}
