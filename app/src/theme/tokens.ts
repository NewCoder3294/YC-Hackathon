// Design tokens — matches frontend/design-handoff/feature-1/frame.jsx TOKENS verbatim.
// Any colour/typography drift between this file and the handoff is a bug.

export const tokens = {
  bgBase:     '#050505',
  bgRaised:   '#0A0A0A',
  bgSubtle:   '#141414',
  bgHover:    '#171717',
  border:     '#262626',
  borderSoft: '#1A1A1A',
  text:       '#FAFAFA',
  textMuted:  '#A3A3A3',
  textSubtle: '#737373',
  live:       '#EF4444',    // red — hot, streak live, record in reach, pinned
  verified:   '#10B981',    // green — Sportradar source, saved style, achievement
  esoteric:   '#F59E0B',    // amber — tactical keyword, formation chip, AI nudge
  stickyBg:   '#F4E27A',    // commentator handwritten note
  stickyText: '#3D2D0A',
} as const;

export type Token = keyof typeof tokens;

// iPad landscape design canvas — matches handoff proportions.
export const IPAD = { WIDTH: 1366, HEIGHT: 1024 } as const;

// Font family string. Use the Google-Fonts-loaded name once loaded,
// with system monospace fallback strings that browsers understand.
export const FONT_MONO = 'IBMPlexMono';

// em-to-px letter-spacing helper. RN letterSpacing is numeric (px).
// Matches handoff values: tracking="0.14em" at fontSize 12 → 12 * 0.14 = 1.68.
export const tracking = (emFraction: number, fontSize: number) => emFraction * fontSize;
