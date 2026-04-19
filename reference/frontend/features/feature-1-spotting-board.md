# Feature 1 — Overnight Auto-Build + Commentator Modes

**Status:** Design handoff landed. Backend integration can start.
**Canonical spec:** [`SPEC.md` §Feature 1](../../SPEC.md)
**Design handoff (verbatim):** [`frontend/design-handoff/feature-1/`](../design-handoff/feature-1/)
**Implementation scaffold:** [`app/`](../../app/) *(kernel only — build out when team is ready)*

---

## What this feature does

Commentator taps a button the night before a match. Gemma 4 on-device fetches squads + stats + storylines + precedent patterns. Overnight, it generates a dense personalized spotting board — one cell per player, matching the density of a veteran broadcaster's handwritten paper board.

In the morning, the commentator opens the iPad and personalizes:
- **Picks a mode** — Stats-first / Story-first / Tactical / Custom
- **Adjusts density** per cell — Compact / Standard / Full
- **Long-presses any stat** to swap it
- **Tap-holds storylines** to reorder or pin
- **Voice-commands widgets** ("Show me Mbappé's shot map")
- **Adds personal annotations** ("Jorge Messi in stands — emotional")
- **Saves as "MY STYLE"** — preferences persist and learn match-to-match

Mode cascades to Features 2 and 3 — same stat request returns different results depending on mode.

---

## Design handoff — how to use it

The handoff at `frontend/design-handoff/feature-1/` is the **pixel-perfect visual source of truth**. It's a working React + Babel-standalone HTML prototype — open it directly in a browser to see the design rendered live:

```bash
open "frontend/design-handoff/feature-1/Feature 1 - Spotting Board.html"
```

Four frames are included:

| Frame | Purpose |
|---|---|
| 1 · Ready | Overnight build complete + mode picker card |
| 2 · Three modes | Same Messi/Mbappé cell rendered Stats / Story / Tactical — for the deck |
| 3 · Personalized | Story mode with sticky-note annotation, pin, density slider, callouts |
| 4 · Hero | Deck screenshot — full context strip, formation mini-pitches, pinned + annotated Messi |

### Handoff file map

```
frontend/design-handoff/
├── README.md                                 ← Claude Design's handoff instructions
└── feature-1/
    ├── Feature 1 - Spotting Board.html       ← open this in a browser
    ├── frame.jsx                             ← iPad frame + shared primitives
    ├── f1-components.jsx                     ← all Feature 1 components
    ├── design-canvas.jsx                     ← Figma-ish pan/zoom wrapper (strip in prod)
    └── assets/                               ← logos + icons used by the HTML
```

---

## Component inventory (from the handoff)

Ported 1:1 from `f1-components.jsx`. Names preserved so backend + frontend can refer to the same vocabulary.

| Component | Source lines | Notes |
|---|---|---|
| `BoardHeader` | f1-components.jsx:6–39 | logo, mode chip, density slider, saved-style badge |
| `ModeChip` | f1-components.jsx:41–53 | current mode with dropdown caret |
| `SavedStyleBadge` | f1-components.jsx:55–69 | persists after "MY STYLE · SAVED" |
| `DensitySlider` | f1-components.jsx:71–89 | Compact / Standard / Full segmented |
| `TeamHeaderF1` | f1-components.jsx:92–116 | per-team column header with formation |
| `MiniPitch` | f1-components.jsx:119–155 | formation visualization, highlights a key player |
| `PlayerCell` | f1-components.jsx:158–237 | **the primary component** — mode-aware body |
| `StatsBody` | f1-components.jsx:240–260 | xG/xA/progressive/pressures/shot %/PPDA grid |
| `StoryBody` | f1-components.jsx:263–285 | hero line + italic narrative beats |
| `TacticalBody` | f1-components.jsx:288–307 | positional role + key tactical metrics |
| `PinBadge` | f1-components.jsx:310–319 | "📌 PINNED" green chip |
| `AddAnnotationBtn` | f1-components.jsx:321–331 | "+ ANNOTATE" dashed button |
| `StickyAnnotation` | f1-components.jsx:333–355 | yellow rotated sticky note |
| `ModePickerCard` | f1-components.jsx:358–401 | onboarding mode selector |
| `ModeOption` / `ModeThumbnail` | f1-components.jsx:403–485 | per-mode row inside picker |
| `BoardEmptyState` | f1-components.jsx:488–517 | "Tap to build your board" CTA |

Shared primitives from `frame.jsx`:

| Component | Purpose |
|---|---|
| `IPadFrame` | 1366×1024 landscape frame with iPadOS status bar |
| `StatusBar` | time + airplane-mode glyph + battery (the "thesis" bar) |
| `SplitLayout` | 60/40 split used by the full MatchScreen |
| `SportradarBadge` | green verified check-mark |

---

## Frontend ↔ Backend coordination points

| What frontend needs | Backend contract |
|---|---|
| Player cells at various densities | `Player.stats.{tournament,career,form_last_5}` — keys chosen by `mode` + `density` |
| Mode-aware storyline ordering | `Storyline.priority_by_mode` |
| Voice-built widgets pre-match | `askGemma({ audio })` returning `widget_spec` |
| Personal annotations persist | `CommentatorProfile.annotations` |
| Stat swap "learning" | `CommentatorProfile.stat_swap_history` + Gemma 4 re-ranking |
| Sticky-note text stored on-device | `CommentatorProfile.annotations: Record<player_id, string>` |
| Pin affordance → priority in Feature 2 | `CommentatorProfile.pinnedPlayerIds` — live pipeline defers to these |

See [`../DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) for full shapes.

### Sample data shapes (from handoff fixtures)

The handoff uses three projections per player. Backend must build each:

```ts
// STATS mode
{ n: '10', pos: 'FW · ARG', name: 'LIONEL MESSI',
  xg: '5.2', xa: '3.1', prog: 47, pressures: 22, shotAcc: '38%', rank: 'TOP-3 WC xG' }

// STORY mode
{ n: '10', pos: 'FW · ARG', name: 'LIONEL MESSI', age: 35,
  storyHero: '5th & final World Cup.',
  storyLines: ['Closes the circle after 2014 loss to Germany.', ...] }

// TACTICAL mode
{ n: '10', pos: 'FW · ARG', name: 'LIONEL MESSI',
  formationRole: '4-3-3 · FREE 10',
  role: 'Drops off Álvarez — occupies right half-space. Drags Tchouaméni out of line.',
  defActions: 3, keyPasses: 18, pressingMap: 'PASSIVE' }
```

All 46 players need all three projections generated overnight from the Sportradar / StatsBomb payload.

---

## Open questions for the backend team

1. **Which stats per position per mode?** The handoff fixes the FW-line defaults. Propose defaults for MF / DF / GK and codify in `DATA_CONTRACTS.md` §4.
2. **Storyline generation pipeline.** Who writes the overnight Gemma 4 prompt that turns raw source articles → `Storyline` objects with `priority_by_mode` scores?
3. **Precedent index seeding.** Need ~30 hand-curated `PrecedentPattern` entries to seed Feature 2. Deadline: before Sprint 3 (5 PM Day 1). Owner?
4. **Sticky-note annotations — plain text or Gemma-aware?** Proposal: plain text, but Gemma 4 reads them as extra context when deciding what to surface live.

---

## Ready-to-implement checklist

- [x] Paste Claude Design handoff → `frontend/design-handoff/feature-1/`
- [x] Drop tokens into `app/src/theme/tokens.ts`
- [x] Update this feature spec with handoff pointers
- [ ] Stand up Expo project (`npx create-expo-app` — see [`app/README.md`](../../app/README.md))
- [ ] Port components 1:1 from `f1-components.jsx` to React Native TypeScript
- [ ] Wire in real `match_cache.json` (backend owns)
- [ ] Verify pixel match against handoff in browser
