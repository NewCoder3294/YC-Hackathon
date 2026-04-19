import React, { createContext, useContext, useEffect, useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';

export type PatternName = 'none' | 'grid-drift' | 'scanlines' | 'dot-pulse' | 'radar-sweep';

// ── Context so any IPadFrame can render the current backdrop without prop-drilling ──
const PatternCtx = createContext<{ pattern: PatternName; setPattern: (p: PatternName) => void }>({
  pattern: 'grid-drift',
  setPattern: () => {},
});

export function PatternProvider({
  children, initial = 'grid-drift',
}: { children: React.ReactNode; initial?: PatternName }) {
  const [pattern, setPattern] = useState<PatternName>(initial);
  return <PatternCtx.Provider value={{ pattern, setPattern }}>{children}</PatternCtx.Provider>;
}

export const usePatternContext = () => useContext(PatternCtx);

export const PATTERN_NAMES: { id: PatternName; label: string }[] = [
  { id: 'none',         label: 'OFF' },
  { id: 'grid-drift',   label: 'GRID DRIFT' },
  { id: 'scanlines',    label: 'SCANLINES' },
  { id: 'dot-pulse',    label: 'DOT PULSE' },
  { id: 'radar-sweep',  label: 'RADAR' },
];

const CSS = `
@keyframes bb-grid-pan {
  0%   { background-position: 0 0; }
  100% { background-position: 44px 44px; }
}
@keyframes bb-scan {
  0%   { transform: translateY(-40%); opacity: 0.0; }
  20%  { opacity: 0.7; }
  100% { transform: translateY(140%); opacity: 0.0; }
}
@keyframes bb-dot-pulse {
  0%, 100% { opacity: 0.25; }
  50%      { opacity: 0.85; }
}
@keyframes bb-radar-rotate {
  0%   { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
`;

let cssInjected = false;
function ensureCSS() {
  if (Platform.OS !== 'web' || cssInjected) return;
  if (typeof document === 'undefined') return;
  const s = document.createElement('style');
  s.id = 'bb-bg-patterns';
  s.textContent = CSS;
  document.head.appendChild(s);
  cssInjected = true;
}

const fill = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 } as const;

export function BackgroundPattern({ pattern }: { pattern: PatternName }) {
  useEffect(ensureCSS, []);
  if (pattern === 'none') return null;

  if (pattern === 'grid-drift') {
    return (
      <View pointerEvents="none" style={{ ...fill, overflow: 'hidden' }}>
        <View
          style={
            {
              ...fill,
              backgroundImage: `linear-gradient(${tokens.border} 1px, transparent 1px), linear-gradient(90deg, ${tokens.border} 1px, transparent 1px)`,
              backgroundSize: '44px 44px',
              animation: 'bb-grid-pan 8s linear infinite',
              opacity: 0.7,
            } as any
          }
        />
      </View>
    );
  }

  if (pattern === 'scanlines') {
    return (
      <View pointerEvents="none" style={{ ...fill, overflow: 'hidden' }}>
        {/* Static fine scanlines */}
        <View
          style={
            {
              ...fill,
              backgroundImage: `repeating-linear-gradient(to bottom, rgba(255,255,255,0.04) 0 1px, transparent 1px 3px)`,
            } as any
          }
        />
        {/* Moving bright sweep band */}
        <View
          style={
            {
              ...fill,
              height: '30%',
              backgroundImage: 'linear-gradient(to bottom, transparent 0%, rgba(239,68,68,0.08) 50%, transparent 100%)',
              animation: 'bb-scan 5s linear infinite',
            } as any
          }
        />
      </View>
    );
  }

  if (pattern === 'dot-pulse') {
    // Static dot grid — no animation.
    return (
      <View pointerEvents="none" style={fill}>
        <View
          style={
            {
              ...fill,
              backgroundImage: `radial-gradient(circle at 1px 1px, ${tokens.border} 1.5px, transparent 1.5px)`,
              backgroundSize: '22px 22px',
              opacity: 0.7,
            } as any
          }
        />
      </View>
    );
  }

  // radar-sweep — conical gradient rotates, faint grid + persistent glow underneath.
  return (
    <View pointerEvents="none" style={{ ...fill, overflow: 'hidden' }}>
      {/* Faint grid */}
      <View
        style={
          {
            ...fill,
            backgroundImage: `linear-gradient(${tokens.borderSoft} 1px, transparent 1px), linear-gradient(90deg, ${tokens.borderSoft} 1px, transparent 1px)`,
            backgroundSize: '64px 64px',
            opacity: 0.35,
          } as any
        }
      />
      {/* Persistent radial glow — always on, gives the "scope" feel */}
      <View
        style={
          {
            ...fill,
            backgroundImage:
              'radial-gradient(circle at 50% 50%, rgba(16,185,129,0.08) 0%, rgba(16,185,129,0.02) 45%, transparent 75%)',
          } as any
        }
      />
      {/* Rotating sweep — wider cone + brighter so it reads from edge to edge */}
      <View
        style={
          {
            position: 'absolute',
            width: '260%',
            height: '260%',
            top: '-80%',
            left: '-80%',
            backgroundImage:
              'conic-gradient(from 0deg, rgba(16,185,129,0) 0deg, rgba(16,185,129,0.28) 20deg, rgba(16,185,129,0.10) 70deg, rgba(16,185,129,0) 100deg, rgba(16,185,129,0) 360deg)',
            animation: 'bb-radar-rotate 6s linear infinite',
            transformOrigin: 'center center',
          } as any
        }
      />
    </View>
  );
}

// Floating dev-mode pill that cycles through patterns. Shown top-right.
export function PatternCycler({
  pattern, onChange,
}: { pattern: PatternName; onChange: (p: PatternName) => void }) {
  return (
    <View
      style={{
        position: 'absolute',
        top: 40,
        right: 20,
        flexDirection: 'row',
        gap: 4,
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: tokens.border,
        borderRadius: 6,
        padding: 4,
        zIndex: 100,
      }}
    >
      {PATTERN_NAMES.map((p) => {
        const active = p.id === pattern;
        return (
          <Pressable
            key={p.id}
            onPress={() => onChange(p.id)}
            style={{
              paddingVertical: 5,
              paddingHorizontal: 9,
              borderRadius: 4,
              backgroundColor: active ? tokens.bgHover : 'transparent',
            }}
          >
            <Text
              style={{
                fontFamily: FONT_MONO,
                fontSize: 9,
                fontWeight: '700',
                letterSpacing: 1.4,
                color: active ? tokens.text : tokens.textSubtle,
              }}
            >
              {p.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}
