# BroadcastBrain

**YC Voice Agents Hackathon 2026 · Cactus × Gemma 4 · Team of 4**

On-device voice AI for sports broadcasters. Always-on co-pilot that listens to the match, surfaces the right stat at the right moment on the commentator's personal spotting board, builds widgets on demand, and answers any question — all on-device, airplane-mode-safe. Validated with 4 working broadcasters.

**Demo match:** Argentina vs France · 2022 FIFA World Cup Final · Lusail Stadium · 18 December 2022.
**Platform:** iPad (landscape) running React Native + Expo + Cactus RN SDK + Gemma 4 multimodal.

---

## Start here

| If you are... | Read... |
|---|---|
| New to the project | [`SPEC.md`](./SPEC.md) — the canonical 3-feature build spec |
| Building UI / designing | [`docs/CLAUDE_DESIGN_PRIMER.md`](./docs/CLAUDE_DESIGN_PRIMER.md) and [`brand-assets/`](./brand-assets/) |
| Planning the sprint | [`docs/SPRINT_PLAN.xlsx`](./docs/SPRINT_PLAN.xlsx) — 11-sprint, 4-track schedule |
| Pitching the startup | [`docs/BroadcastBrain_1Pager.pdf`](./docs/BroadcastBrain_1Pager.pdf) |
| Questioning the problem | [`docs/Broadcaster_Research.pdf`](./docs/Broadcaster_Research.pdf) — 4 broadcaster interviews |
| Setting up Cactus | [`README.md`](./README.md) — original hackathon template |

---

## The 3 features

1. **Overnight Auto-Build + Commentator Modes** — Gemma 4 on-device generates a dense spotting board overnight. Commentator picks a mode (Stats-first / Story-first / Tactical) and personalizes every cell. Learns "my style" over time.
2. **Live Co-Pilot Board** — always-on. Autonomous 3-card stacks on key events (stat + precedent + counter-narrative), plus voice-commanded widgets the commentator builds on the fly. Running score, story queue, streak alerts auto-maintained.
3. **Voice Commands + Queries** — single press-to-talk button routes by phrasing: "Show me…" → widget; "How does…" → sourced answer; ungrounded → "I don't have verified data on that." Same button pre-match, mid-match, post-match.

---

## Tech stack

- **Platform:** iPad (landscape), iPadOS 16+
- **Framework:** React Native + Expo
- **LLM:** Gemma 4 multimodal on-device via Cactus (YC S25)
- **Complex queries:** Gemini via Cactus hybrid routing (cloud fallback only — demo stays airplane-mode)
- **Data:** Sportradar (or StatsBomb Open Data for 2022 WC archive) — pre-cached as `match_cache.json`
- **State:** Zustand event bus
- **Audio:** expo-av (rolling capture + press-to-talk)
- **TTS:** expo-speech (Feature 3 opt-in only)

---

## Non-negotiables

1. Every stat carries `Sportradar ✓` source badge. Missing data = `—`, never guessed.
2. Airplane-mode indicator visible in iPadOS status bar on every screen.
3. Visual-first, silent by default. Zero popups, no modal interruptions.
4. The commentator stays in control — AI surfaces, commentator decides.

---

## Design system quick reference

- **Background:** `#050505` / `#0A0A0A` / `#141414`
- **Accents:** `#EF4444` (live), `#10B981` (verified), `#F59E0B` (AI nudge)
- **Type:** IBM Plex Mono throughout
- Full tokens + icon reference in [`brand-assets/README.md`](./brand-assets/README.md)

---

## Repo layout

```
YC-Hackathon/
├── README.md                     ← original hackathon template (Cactus setup)
├── BROADCASTBRAIN.md             ← you are here
├── SPEC.md                       ← 3-feature build spec (v2, canonical)
├── docs/
│   ├── SPEC_v1_full_vision.md    ← original full-vision spec (context only)
│   ├── SPRINT_PLAN.xlsx          ← 11-sprint 4-track schedule
│   ├── CLAUDE_DESIGN_PRIMER.md   ← paste-ready brief for Claude Design
│   ├── BroadcastBrain_1Pager.pdf ← investor/judge pitch 1-pager
│   ├── BroadcastBrain_PatMcCarthy.pdf ← broadcaster-facing version
│   └── Broadcaster_Research.pdf  ← 4 broadcaster interviews (Pat, Bob, Rich, Trey)
├── brand-assets/                 ← royalty-free SVG design pack
│   ├── README.md                 ← design tokens & usage
│   ├── logo/ · icons/ · ui/
│   ├── backgrounds/ · hero/
│   ├── product/ · illustrations/ · decorative/
│   └── PHOTO-GUIDE.md
└── assets/                       ← from original hackathon template (Cactus banner)
```

---

## Demo script (5 min)

Full script in `SPEC.md` §Demo Script. Three beats judges remember:

1. Airplane-mode indicator on the iPad status bar the entire demo.
2. Latency counter showing a real sub-1-second number.
3. Peter Drury's Messi call playing as live audio → stat card lands before the reverb decays.
