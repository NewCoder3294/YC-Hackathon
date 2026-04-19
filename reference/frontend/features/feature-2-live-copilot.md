# Feature 2 — Live Co-Pilot (autonomous + voice-commanded)

**Status:** Design handoff landed. Backend integration can start.
**Canonical spec:** [`SPEC.md` §Feature 2](../../SPEC.md)
**Design handoff (verbatim):** [`frontend/design-handoff/feature-2/`](../design-handoff/feature-2/)
**Pickup prompt:** [`FEATURE_2_PICKUP.md`](../../FEATURE_2_PICKUP.md)

---

## What this feature does

The iPad's always-on co-pilot during the match. Two input modes, one canvas:

### Mode A — Autonomous (AI-initiated)

Gemma 4 listens continuously. When the AI detects something stat-worthy (goal, big chance, sub, card, VAR, half-time transition), it surfaces a **3-card stack** on the Live Pane:

1. **Stat card** — the player-specific moment (scorer, shot-taker, booked player)
2. **Precedent card** — the broader pattern (*"Teams leading 2-0 in WC Finals have won 19/22 since 1970"*)
3. **Counter-narrative card** — drama for the losing side's fans (*"BUT 2/22 came back — both in ET"*)

Plus ambient widgets: **running score**, **momentum tags**, **story reminder queue** (with STT dup-suppression), **streak alerts**.

### Mode B — Voice-commanded (commentator-initiated, press-to-talk)

One button, bottom bezel, press-and-hold. Gemma 4 auto-routes by phrasing:

| Phrasing | Outcome | Event emitted |
|---|---|---|
| "Show me / Pull up / Track …" | Widget materializes on Live Pane (pinnable) | `widget_built` |
| "How does / What's / Compare …" | Sourced answer card + (opt-in) TTS | `answer_card` |
| Ungrounded (no verified data) | Trust escape: *"I don't have verified data on that."* | `no_data` |

Both modes share the same `askGemma` contract and function toolbox. The only difference is the entry event.

---

## Design handoff — how to use it

```bash
open "frontend/design-handoff/feature-2/Feature 2 - Live Dashboard.html"
```

Opens the pixel-perfect prototype in a browser. Also reference `screenshots/f2-final.jpg` as the hero frame for the submission deck.

### Handoff file map

```
frontend/design-handoff/feature-2/
├── Feature 2 - Live Dashboard.html         ← open this in a browser
├── right-pane.jsx                          ← all Feature 2 right-pane components
├── screenshots/
│   ├── f2-check.jpg                        ← design audit snapshot
│   ├── f2-final.jpg                        ← deck-ready hero frame
│   └── f2-overview.jpg                     ← full canvas overview
└── assets/                                 ← SVGs shared with Feature 1 handoff
```

Shared primitives (iPad frame, status bar, split layout, Sportradar badge, live pill, latency tag) live in [`frontend/design-handoff/feature-1/frame.jsx`](../design-handoff/feature-1/frame.jsx). Reuse them — do not rebuild.

---

## Component inventory (from `right-pane.jsx`)

Ported 1:1 from the handoff. Names preserved for cross-team vocabulary.

| Component | Source lines | Purpose |
|---|---|---|
| `LivePaneShell` | right-pane.jsx:11–81 | Top bar (score + clock + listening dot) · body · bottom bezel |
| `ListeningDot` | right-pane.jsx:83–101 | Always-on "AI is listening" indicator (top-right) |
| `BottomBezel` | right-pane.jsx:104–136 | Press-and-hold voice button + latency tag |
| `Waveform` | right-pane.jsx:138–149 | Animated waveform during listening state |
| `CardStack` | right-pane.jsx:161–167 | Vertical stack wrapper for the 3-card pattern |
| `StackCard` | right-pane.jsx:169–199 | Card primitive with left-edge colour by kind (stat/precedent/counter) |
| `ScorerStatCard` | right-pane.jsx:201–243 | **Stat card** — the player-specific moment |
| `PrecedentCard` | right-pane.jsx:245–268 | **Precedent card** — historical pattern match |
| `CounterNarrativeCard` | right-pane.jsx:270–292 | **Counter-narrative card** — drama for the losing side |
| `RunningScorePanel` | right-pane.jsx:295–334 | Goal timeline + momentum tags (replaces Bob's handwritten page) |
| `EmptyGridlines` | right-pane.jsx:336–347 | Pre-KO placeholder for running score |
| `StoryQueue` | right-pane.jsx:350–387 | Pre-planned storylines, STT auto-ticks when mentioned |
| `TranscriptOverlay` | right-pane.jsx:390–409 | "You said: …" transcript shown above voice-built widgets |
| `VoiceWidget` | right-pane.jsx:411–465 | **The voice-commanded widget** (pinnable horizontal timeline) |
| `WidgetBtn` | right-pane.jsx:467–479 | Widget action controls (pin, dismiss) |

Shared primitives (inherited from Feature 1 handoff): `IPadFrame`, `SplitLayout`, `StatusBar`, `SportradarBadge`, `LivePill`, `LatencyTag`.

---

## Frontend ↔ Backend coordination points

| What frontend needs | Backend contract |
|---|---|
| 3-card stack on every goal/event | Gemma 4 emits 3 events: `stat_card` + `precedent` + `counter_narrative` |
| Running score auto-built from PBP | Backend subscribes to match events, emits `running_score` + `momentum_tag` |
| Story queue auto-ticks via STT | STT stream → backend matches against `pinned_storyline_ids` → emits `story_tick` |
| Voice-built widgets (any shape) | Gemma 4 function-calls → emits `widget_built` with `WidgetSpec` |
| Voice-queried answer card | Gemma 4 function-calls → emits `answer_card` |
| Trust escape when ungrounded | Gemma 4 refuses to fabricate → emits `no_data` |
| Streak alerts pre-computed | Backend precomputes active streaks at overnight build → emits `streak_alert` when at risk |

See [`../DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) §3 for exact event shapes.

### Precedent engine — seed requirement

Feature 2's counter-narrative and precedent cards are only as good as the precedent index. Need **~30 hand-curated `PrecedentPattern` entries** seeded at overnight build. Examples for the Arg vs Fra 2022 match:

```ts
{ id: 'lead_2_0_wc_final',
  trigger: { event_type: 'goal', score_state: 'trailing_team_down_2' },
  stat_text: 'Teams leading 2-0 in WC Finals have won 19/22 since 1970',
  counter_narrative: 'BUT 2/22 came back — both in extra time. 1966 ENG vs WG, 1994 ITA vs BRA',
  category: 'historical' }

{ id: 'mbappe_age_23_scorer',
  trigger: { event_type: 'goal', player_filters: { age_lt: 24 } },
  stat_text: 'Mbappé is first player under 24 to score in two WC Finals since Pelé',
  category: 'statistical' }

{ id: 'france_comebacks_wc',
  trigger: { event_type: 'goal', score_state: 'fra_trailing' },
  stat_text: 'France came back from 1-0 down to win the 2018 Final (4-2 vs Croatia)',
  counter_narrative: 'Mbappé scored that day',
  category: 'emotional' }
```

Who owns this seeding? Open question below.

---

## Open questions for the backend team

1. **Precedent index owner + deadline.** Needs ~30 entries seeded before Sprint 3 (5 PM Day 1). Who's writing them?
2. **Voice-command intent classification.** Does Gemma 4 classify the phrasing locally, or do we pattern-match client-side (starts with "show me" → COMMAND, starts with "how" → QUERY)? Proposal: let Gemma 4 classify — simpler, more robust to weird phrasings. Needs testing.
3. **Widget shapes.** `WidgetSpec.kind` in DATA_CONTRACTS is enumerated as `timeline | bar_chart | comparison_table | heat_map | shot_map`. Is that sufficient for the demo? Likely need just `timeline` + `comparison_table` for the 2 demo beats.
4. **Running-score source.** Pull from Sportradar PBP feed (real-time subscription) or from pre-baked `match_cache.json` events? For airplane-mode demo, must be from cache. Who bakes the PBP timeline into the cache?
5. **STT dup-suppression threshold.** If the commentator mentions Messi's streak stat on-air, how exact does the match need to be before we mark it "used"? Proposal: fuzzy match on key phrase + player name, 10-second cooldown.

---

## Ready-to-implement checklist

- [x] Paste Claude Design handoff → `frontend/design-handoff/feature-2/`
- [x] Update this feature spec with handoff pointers
- [x] Update `SPEC.md` with merged Feature 2 (voice-commanded subsection)
- [ ] Seed ~30 `PrecedentPattern` entries into `assets/match_cache.json`
- [ ] Backend: implement Gemma 4 function toolbox per `DATA_CONTRACTS.md §2`
- [ ] Cactus/Gemma 4: wire `askGemma` to emit the correct event type based on input path (autonomous vs voice-commanded)
- [ ] Frontend: port `right-pane.jsx` components 1:1 into `app/src/components/feature2/*.tsx`
- [ ] Wire components to Zustand event bus
- [ ] Verify pixel match against handoff in browser
