// Design tokens with runtime theme switching via CSS custom properties.
// Each token emits `var(--bb-X, <dark-fallback>)` — changing the CSS variables
// on the document root re-themes the entire app with zero React re-renders.

import { Platform } from 'react-native';
import { create } from 'zustand';

const IS_WEB = Platform.OS === 'web';

export type ThemeMode = 'dark' | 'light';

const DARK = {
  bgBase:     '#050505',
  bgRaised:   '#0A0A0A',
  bgSubtle:   '#141414',
  bgHover:    '#171717',
  border:     '#262626',
  borderSoft: '#1A1A1A',
  text:       '#FAFAFA',
  textMuted:  '#A3A3A3',
  textSubtle: '#737373',
  live:       '#EF4444',
  verified:   '#10B981',
  esoteric:   '#F59E0B',
  stickyBg:   '#F4E27A',
  stickyText: '#3D2D0A',
  shadowCard:   '0 18px 50px rgba(255,255,255,0.08), 0 0 0 1px rgba(255,255,255,0.05)',
  shadowStrong: '0 24px 60px rgba(255,255,255,0.1), 0 0 0 1px rgba(255,255,255,0.06)',
  shadowDrawer: '-14px 0 40px rgba(255,255,255,0.08)',
} as const;

const LIGHT = {
  bgBase:     '#F5F5F5',
  bgRaised:   '#FFFFFF',
  bgSubtle:   '#EDEDED',
  bgHover:    '#E4E4E4',
  border:     '#D4D4D4',
  borderSoft: '#E5E5E5',
  text:       '#0A0A0A',
  textMuted:  '#525252',
  textSubtle: '#737373',
  live:       '#DC2626',
  verified:   '#059669',
  esoteric:   '#B45309',
  stickyBg:   '#FFF4A3',
  stickyText: '#3D2D0A',
  shadowCard:   '0 18px 50px rgba(0,0,0,0.18), 0 2px 8px rgba(0,0,0,0.08)',
  shadowStrong: '0 24px 60px rgba(0,0,0,0.25), 0 4px 12px rgba(0,0,0,0.12)',
  shadowDrawer: '-14px 0 40px rgba(0,0,0,0.2)',
} as const;

const PALETTES: Record<ThemeMode, Record<keyof typeof DARK, string>> = { dark: DARK, light: LIGHT };

const VAR = {
  bgBase:     '--bb-bg-base',
  bgRaised:   '--bb-bg-raised',
  bgSubtle:   '--bb-bg-subtle',
  bgHover:    '--bb-bg-hover',
  border:     '--bb-border',
  borderSoft: '--bb-border-soft',
  text:       '--bb-text',
  textMuted:  '--bb-text-muted',
  textSubtle: '--bb-text-subtle',
  live:       '--bb-live',
  verified:   '--bb-verified',
  esoteric:   '--bb-esoteric',
  stickyBg:   '--bb-sticky-bg',
  stickyText: '--bb-sticky-text',
  shadowCard:   '--bb-shadow-card',
  shadowStrong: '--bb-shadow-strong',
  shadowDrawer: '--bb-shadow-drawer',
} as const;

type TokenKey = keyof typeof VAR;

function buildTokens(): Record<TokenKey, string> {
  const out = {} as Record<TokenKey, string>;
  (Object.keys(VAR) as TokenKey[]).forEach((key) => {
    // Web: emit CSS var() so runtime theme switching via document.documentElement works.
    // Native iOS/Android: var() is invalid and renders as transparent/black, causing the
    // "shadow over the entire app" bug — emit the raw dark hex value instead.
    out[key] = IS_WEB ? `var(${VAR[key]}, ${DARK[key]})` : DARK[key];
  });
  return out;
}

export const tokens = buildTokens();
export type Token = TokenKey;

function applyTheme(mode: ThemeMode) {
  if (typeof document === 'undefined') return;
  const palette = PALETTES[mode];
  const root = document.documentElement;
  (Object.keys(VAR) as TokenKey[]).forEach((key) => {
    root.style.setProperty(VAR[key], palette[key]);
  });
  root.style.colorScheme = mode;
  root.style.backgroundColor = palette.bgBase;
}

interface ThemeState {
  mode: ThemeMode;
  setMode: (m: ThemeMode) => void;
  toggle: () => void;
}

export const useTheme = create<ThemeState>((set, get) => ({
  mode: 'dark',
  setMode: (mode) => {
    applyTheme(mode);
    set({ mode });
  },
  toggle: () => {
    const next: ThemeMode = get().mode === 'dark' ? 'light' : 'dark';
    applyTheme(next);
    set({ mode: next });
  },
}));

// Apply initial theme on module load (web only — safe no-op elsewhere).
if (typeof document !== 'undefined') {
  applyTheme('dark');
}

// iPad landscape design canvas — matches handoff proportions.
export const IPAD = { WIDTH: 1366, HEIGHT: 1024 } as const;

// Font family string. Use the Google-Fonts-loaded name once loaded,
// with system monospace fallback strings that browsers understand.
export const FONT_MONO = 'IBMPlexMono';

// em-to-px letter-spacing helper. RN letterSpacing is numeric (px).
// Matches handoff values: tracking="0.14em" at fontSize 12 → 12 * 0.14 = 1.68.
export const tracking = (emFraction: number, fontSize: number) => emFraction * fontSize;
