# app/ — Frontend implementation scaffold

Landing spot for the React Native + Expo iPad implementation. Populated incrementally as each feature's design handoff lands.

## Current state

| Feature | Handoff | Implementation |
|---|---|---|
| 1 · Spotting Board | ✅ `frontend/design-handoff/feature-1/` | 🟡 kernel only (`theme/tokens.ts`) |
| 2 · Live Dashboard | ⏳ pending | — |
| 3 · Voice Query | ⏳ pending | — |

## Build setup (when you're ready to stand up Expo)

```bash
# From repo root
npx create-expo-app@latest ./app --template blank-typescript
cd app
npm install @expo-google-fonts/ibm-plex-mono react-native-svg zustand
# Copy src/ contents into the newly-created project's root
```

## File layout

```
app/
├── README.md                                ← this file
└── src/
    ├── theme/tokens.ts                      ← design tokens (colour, typography, sizes)
    ├── types/                               ← TS types (Player shapes, Mode, Density)
    ├── data/                                ← fixtures from the handoff (temporary)
    └── components/
        ├── common/                          ← cross-feature primitives
        └── feature1/                        ← Feature 1 components
```

## Build order (when team is ready)

1. Run `npx create-expo-app` + install deps above
2. Port the feature-1 components straight from `frontend/design-handoff/feature-1/f1-components.jsx`:
   - web `<div>` → RN `<View>`
   - inline style objects → RN `StyleSheet.create`
   - SVG elements → `react-native-svg`
3. Components to implement, in order: `PlayerCell` → `BoardHeader` → `ModePickerCard` → `MiniPitch` → `StickyAnnotation`
4. Match visual output to the handoff frames pixel-for-pixel — the handoff HTML renders live in a browser as the ground truth.

## Non-negotiables (enforced in every PR)

- Every stat shows `Sportradar ✓`. Missing data = `—`, never guessed.
- iPadOS airplane-mode indicator visible in status bar on every screen.
- Visual-first, silent by default. No modals.
- Commentator stays in control — AI surfaces, commentator decides.
