# Feature 1 — Overnight Auto-Build + Commentator Modes

**Status:** Design handoff pending paste.
**Canonical spec:** [`SPEC.md` §Feature 1](../../SPEC.md)
**Frames:** [`frontend/frames/feature-1/`](../frames/feature-1/)

---

## What this feature does

Commentator taps a button the night before a match. Gemma 4 on-device fetches squads + stats + storylines + precedent patterns. Overnight, it generates a dense personalized spotting board — one cell per player, ~15 data points each, matching the density of a veteran broadcaster's handwritten paper board.

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

## Frontend ↔ Backend coordination points

| What frontend needs | Backend contract |
|---|---|
| Player cells at various densities | `Player.stats.{tournament,career,form_last_5}` — keys chosen by `mode` + `density` |
| Mode-aware storyline ordering | `Storyline.priority_by_mode` |
| Voice-built widgets pre-match | `askGemma({ audio })` returning `widget_spec` |
| Personal annotations persist | `CommentatorProfile.annotations` |
| Stat swap "learning" | `CommentatorProfile.stat_swap_history` + Gemma 4 re-ranking |

See [`../DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) for full shapes.

---

## Component inventory

*(Populated from Claude Design handoff.)*

```tsx
// High-level; populate via handoff paste
<SpottingBoardPane>
  <MatchContextStrip />                     // top: competition / venue / H2H / weather
  <ModePickerCard />                        // shown once per match before commentator picks
  <SquadColumn team="home">
    <PlayerCell density="standard" ... />   // ×11 starters + subs
  </SquadColumn>
  <SquadColumn team="away"> ... </SquadColumn>
  <FloatingAffordances />                   // long-press menus, voice button
</SpottingBoardPane>
```

---

## Claude Design handoff

> **PASTE HERE** — the full handoff content from Claude Design (component names, prop shapes, animation timings, exact spacing, token usage). Keep the markdown structure the design produced; don't reformat.

<!--
PLACEHOLDER — DO NOT REMOVE. REPLACE THIS BLOCK WITH THE PASTED HANDOFF.

Expected content:
- Component names + prop shapes (React Native style)
- Animation timings (ms) — mode picker reveal, cell mode transition, widget pin,
  density slider animations, annotation entry
- Exact spacing (px) — cell padding, stat row height, column gutter
- Token usage — which tokens from brand-assets/README.md go where
- Hero frame reference → frontend/frames/feature-1/frame-4-hero.png
-->

---

## Open questions for the backend team

1. **Which stats per position per mode?** We need a default mapping. Proposal:
   - **FW, stats-first:** goals, xG, xA, progressive carries, shot accuracy, successful take-ons
   - **FW, story-first:** goals, assists, apps (keep minimal)
   - **FW, tactical:** pressures, final-third entries, expected goals on target, shot placement zones
   - Same logic for MF, DF, GK. Let's codify in `DATA_CONTRACTS.md` §4 once agreed.

2. **Storyline generation pipeline.** Who writes the overnight Gemma 4 prompt that turns raw source articles → `Storyline` objects with `priority_by_mode` scores?

3. **Precedent index seeding.** We need ~30 hand-curated `PrecedentPattern` entries to seed Feature 2. Deadline: before Sprint 3 (5 PM Day 1). Owner?

4. **Personal annotations — free text or tagged?** Proposal: free text. Gemma 4 reads them as extra context when deciding what to surface live.

---

## Ready-to-implement checklist (when handoff lands)

- [ ] Paste Claude Design handoff above (replaces placeholder)
- [ ] Drop hero PNG into [`frontend/frames/feature-1/frame-4-hero.png`](../frames/feature-1/)
- [ ] Open PR with handoff + frames + component inventory fleshed out
- [ ] Backend team reads → proposes `match_cache.json` stubs → merges
- [ ] Frontend dev (Track D) begins building `SpottingBoardPane` against the spec
