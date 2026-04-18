# Feature 1 · Pickup Prompt for Claude Code

**Use this when joining the team or resuming work on Feature 1 (Pre-match Auto Spotting Board).**
Paste the relevant block into a fresh Claude Code session in your local clone of this repo. Claude will read the canonical files, orient itself, then ask you for your track and hand you a concrete first task.

The shared memory lives in the repo (`SPEC.md`, `frontend/DATA_CONTRACTS.md`, `frontend/features/feature-1-spotting-board.md`, `frontend/design-handoff/feature-1/`). The prompt below is just a pointer-map.

---

## Universal pickup prompt (use if unsure which track)

```
I'm on the BroadcastBrain team building an on-device voice AI for sports
broadcasters for the YC Voice Agents Hackathon 2026. Platform: iPad
(landscape) running React Native + Expo + Cactus RN SDK + Gemma 4 multimodal.
Demo match: Argentina vs France 2022 FIFA World Cup Final.

Feature 1 (Pre-match Auto Spotting Board) has its design handoff landed and
is ready for integration. Before writing any code, read these in order:

1. BROADCASTBRAIN.md — project orientation
2. SPEC.md §Feature 1 — canonical spec
3. frontend/DATA_CONTRACTS.md — typed shapes bridging frontend/backend
4. frontend/features/feature-1-spotting-board.md — component inventory with
   source-line references into the handoff
5. frontend/design-handoff/feature-1/Feature 1 - Spotting Board.html — open
   in a browser to see the design render live (React + Babel standalone)
6. frontend/design-handoff/feature-1/f1-components.jsx — the ~16 components
   to be either rebuilt in RN or fed with data

Then tell me which track I'm on:

- DATA/BACKEND — build match_cache.json from Sportradar/StatsBomb, implement
  the Gemma 4 function toolbox (get_player_stat, get_team_stat,
  get_historical, get_match_context, get_commentator_profile), and the
  overnight generation pipeline that produces the 3 projections
  (stats/story/tactical) per player.
- FRONTEND/UI — stand up Expo (see app/README.md), port components from
  f1-components.jsx to React Native TypeScript pixel-for-pixel, wire to
  mock data until backend lands. Tokens already in app/src/theme/tokens.ts.
- CACTUS/GEMMA 4 — wrap Cactus RN into the askGemma(input, context, routing)
  contract defined in DATA_CONTRACTS §5, wire the function toolbox, prove
  Gemma 4 multimodal audio input works on iPad.

Non-negotiables regardless of track:
1. Every stat shows "Sportradar ✓". Missing data = "—", never guessed.
2. iPadOS airplane-mode indicator visible on every screen (the demo's thesis).
3. All demo paths run in airplane mode — cloud routing only for non-demo
   complex historicals.
4. Visual-first, silent by default. No modals, no popups.
5. Commentator stays in control — AI surfaces, commentator decides.

Give me one concrete first task that takes ≤2 hours and closes an integration
seam (not a speculative scaffold). Consider what's blocking other tracks.
```

---

## Role-specific pickup prompts

### DATA / BACKEND

```
BroadcastBrain YC Hackathon. Pull the latest main.

Read SPEC.md §Feature 1 and frontend/DATA_CONTRACTS.md end-to-end.

My job: build assets/match_cache.json for the 2022 Argentina vs France WC
Final matching the shape in DATA_CONTRACTS §1, and implement the Gemma 4
function toolbox in §2. All 46 players need three projections
(stats/story/tactical) per the sample fixtures in
frontend/features/feature-1-spotting-board.md.

Source options: Sportradar Soccer API (trial) or StatsBomb Open Data (this
match is in their free archive). Every stat needs a verifiable source for
the Sportradar ✓ badge.

Non-negotiables:
- Missing data = "—", never guessed
- Every stat carries a source
- Airplane-mode-safe — match_cache.json bundles with the app

What's my first concrete task (≤2 hours)?
```

### FRONTEND / UI

```
BroadcastBrain YC Hackathon. Pull the latest main.

Read SPEC.md §Feature 1. Then open
frontend/design-handoff/feature-1/Feature 1 - Spotting Board.html in a
browser to see the design render live.

My job: stand up the Expo RN project in app/ (see app/README.md), port
components from frontend/design-handoff/feature-1/f1-components.jsx to
React Native TypeScript pixel-for-pixel. Tokens already in
app/src/theme/tokens.ts. Target device: iPad landscape. Use mock data from
the handoff fixtures (MESSI_STATS, MESSI_STORY, MESSI_TACTICAL etc.) until
backend ships match_cache.json.

Start with PlayerCell (the flagship component, f1-components.jsx:158–237)
— everything else is scaffolding around it.

Non-negotiables:
- Every stat card shows "Sportradar ✓"
- iPadOS airplane-mode glyph visible in status bar on every screen
- Visual-first, silent by default (no modals/popups)
- IBM Plex Mono throughout

What's my first concrete task (≤2 hours)?
```

### CACTUS / GEMMA 4

```
BroadcastBrain YC Hackathon. Pull the latest main.

Read SPEC.md §Shared Architecture plus frontend/DATA_CONTRACTS.md §2 and §5.

My job: wrap Cactus RN SDK into the askGemma(input, context, routing)
contract in DATA_CONTRACTS §5. This is the single integration seam all
three features call. Then wire the Gemma 4 function toolbox from §2 so
Gemma 4 can call get_player_stat etc. locally against the bundled
match_cache.json.

Critical de-risker to resolve FIRST: does Cactus RN SDK expose Gemma 4
multimodal audio input directly in JS, or do I need an Expo config plugin
+ native module wrapping the iOS Cactus SDK? Resolve this before anything
else — it affects every other track.

What's my first concrete task (≤2 hours)?
```

---

## Why the "≤2-hour task" ending matters

Without it, a fresh Claude tends to scaffold endlessly — it produces a ten-step plan instead of shipping. That line forces it to pick the highest-leverage unblocker and start. Keep it in the prompt.
