# Frontend — BroadcastBrain iPad App

React Native + Expo, landscape iPad. Split layout: **Spotting Board pane** (left ~60%) and **Live Dashboard pane** (right ~40%). Single `MatchScreen` hosts both panes; no tab switching during a match.

---

## Purpose of this folder

Ground-truth frontend specifications for backend collaborators. Read this before writing:
- `match_cache.json` generators
- Gemma 4 function implementations (`get_player_stat`, etc.)
- Zustand event bus payloads
- `askGemma` response shapes

If you change a contract here, also change `DATA_CONTRACTS.md` and open a conversation — the frontend will break silently if we drift.

---

## Start here

| You are... | Read |
|---|---|
| Building the data pipeline | [`DATA_CONTRACTS.md`](./DATA_CONTRACTS.md) |
| Implementing a feature | [`features/feature-1-spotting-board.md`](./features/feature-1-spotting-board.md) (and the other two when ready) |
| Looking for screenshot references | [`frames/`](./frames/) |

---

## Architecture recap

```
┌─ iPad (React Native + Expo) ─────────────────────────────────────┐
│                                                                   │
│  Screens                                                          │
│    └─ MatchScreen                                                 │
│         ├─ SpottingBoardPane  (Feature 1: commentator playground)│
│         └─ LiveDashboardPane  (Features 2 + 3: live + voice)     │
│                                                                   │
│  State: Zustand event bus (see DATA_CONTRACTS.md §3)             │
│                                                                   │
│  Pipeline: audio → askGemma → event bus → panes                  │
│                                                                   │
│  Cactus RN SDK → Gemma 4 on-device (multimodal)                  │
│    STT · function calls · structured output · optional Gemini    │
│    routing for complex historical queries                         │
│                                                                   │
│  Data: assets/match_cache.json (bundled, airplane-mode safe)      │
└───────────────────────────────────────────────────────────────────┘
```

---

## Non-negotiables (check every PR against these)

1. Every stat shows `Sportradar ✓`. Missing data = `—`, never guessed.
2. iPadOS airplane-mode indicator visible on every screen.
3. Visual-first, silent by default. No modals. No interruptions.
4. Commentator stays in control — AI surfaces, commentator decides.
5. All live-demo paths run airplane-mode; Gemini cloud routing only for non-demo complex queries.
