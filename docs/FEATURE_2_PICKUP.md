# Feature 2 · Pickup Prompt for Claude Code

**Use this when joining the team or resuming work on Feature 2 (Live Co-Pilot).**
Paste the relevant block into a fresh Claude Code session in your local clone of this repo. Claude will read the canonical files, orient itself, then ask you for your track and hand you a concrete first task.

The shared memory lives in the repo (`SPEC.md`, `frontend/DATA_CONTRACTS.md`, `frontend/features/feature-2-live-copilot.md`, `frontend/design-handoff/feature-2/`). The prompt below is just a pointer-map.

---

## Universal pickup prompt (use if unsure which track)

```
I'm on the BroadcastBrain team building an on-device voice AI for sports
broadcasters for the YC Voice Agents Hackathon 2026. Platform: iPad
(landscape) running React Native + Expo + Cactus RN SDK + Gemma 4 multimodal.
Demo match: Argentina vs France 2022 FIFA World Cup Final.

Feature 2 (Live Co-Pilot) is the always-on during-match surface. It has two
input modes on one shared canvas (the Live Pane):
  A) Autonomous — Gemma 4 surfaces 3-card stacks (stat + precedent +
     counter-narrative) on events, plus running score, streak alerts,
     story queue.
  B) Voice-commanded — press-to-talk button routes by phrasing:
     "Show me X" → widget; "How does X" → sourced answer + TTS;
     ungrounded → "I don't have verified data on that."

Design handoff is landed. Feature 1 is also already shipped — you can
reference it for shared primitives (IPadFrame, StatusBar, SplitLayout,
SportradarBadge, LivePill, LatencyTag).

Before writing any code, read these in order:

1. BROADCASTBRAIN.md — project orientation
2. SPEC.md §Feature 2 — canonical spec (2 features total, not 3 — Feature 3
   collapsed into Feature 2's voice-commanded path)
3. frontend/DATA_CONTRACTS.md — typed shapes bridging frontend/backend
   (pay attention to §3 event bus and §5 askGemma contract)
4. frontend/features/feature-2-live-copilot.md — component inventory
   with source-line references into the handoff
5. frontend/design-handoff/feature-2/Feature 2 - Live Dashboard.html —
   open in a browser to see the design render live
6. frontend/design-handoff/feature-2/right-pane.jsx — the 15 right-pane
   components (LivePaneShell, CardStack, ScorerStatCard, PrecedentCard,
   CounterNarrativeCard, RunningScorePanel, StoryQueue, VoiceWidget, ...)
7. frontend/design-handoff/feature-1/frame.jsx — SHARED primitives
   (IPadFrame, StatusBar, SplitLayout, SportradarBadge, LivePill,
   LatencyTag) — reuse, do not rebuild

Then tell me which track I'm on:

- DATA/BACKEND — seed ~30 PrecedentPattern entries into match_cache.json,
  implement the Gemma 4 function toolbox in DATA_CONTRACTS §2
  (get_player_stat, get_team_stat, get_historical, get_match_context),
  and build the PBP event timeline so RunningScorePanel auto-populates.
- FRONTEND/UI — port right-pane.jsx components 1:1 to React Native
  TypeScript. LivePaneShell is the frame; CardStack + ScorerStatCard +
  PrecedentCard + CounterNarrativeCard are the 3-card pattern;
  RunningScorePanel + StoryQueue are ambient widgets; VoiceWidget is
  the voice-commanded pinnable widget. Tokens in app/src/theme/tokens.ts.
- CACTUS/GEMMA 4 — wire askGemma to emit the right event based on input
  path: autonomous audio → stat_card + precedent + counter_narrative
  events; press-to-talk audio → widget_built OR answer_card OR no_data
  event, routed by Gemma 4's intent classification of the phrasing.
  Trust escape ("I don't have verified data") must work — never
  fabricate. See DATA_CONTRACTS §3.

Non-negotiables regardless of track:
1. Every stat shows "Sportradar ✓". Missing data = "—", never guessed.
2. iPadOS airplane-mode indicator visible on every screen (the demo's thesis).
3. All demo paths run in airplane mode — cloud routing only for non-demo
   complex historicals.
4. Visual-first, silent by default. No modals, no popups. The AI NEVER
   interrupts the commentator's call — cards appear, never force attention.
5. Commentator stays in control — AI surfaces, commentator decides.
6. No confidence tiers in the UI. Either we trust the stat or we don't
   show it. Binary. (Behind the scenes Gemma 4's confidence may gate TTS,
   but the commentator never sees "~" or "medium confidence" labels.)

Give me one concrete first task that takes ≤2 hours and closes an
integration seam (not a speculative scaffold). Consider what's blocking
other tracks right now.
```

---

## Role-specific pickup prompts

### DATA / BACKEND

```
BroadcastBrain YC Hackathon — Feature 2. Pull the latest main.

Read SPEC.md §Feature 2 and frontend/DATA_CONTRACTS.md (especially §1 for
PrecedentPattern shape and §2 for the function toolbox).

My job:
1) Seed ~30 hand-curated PrecedentPattern entries into match_cache.json.
   Examples in frontend/features/feature-2-live-copilot.md §Precedent
   engine — seed requirement. Cover: WC Final lead-holding patterns,
   comeback patterns (for counter-narrative cards), age-record patterns,
   national team WC final appearances.
2) Implement the Gemma 4 function toolbox: get_player_stat, get_team_stat,
   get_match_context, get_historical. All resolve against the in-memory
   match_cache.json — zero network calls during the demo.
3) Build a PBP (play-by-play) event timeline baked into match_cache.json
   so RunningScorePanel can show real goal events from the 2022 Arg vs
   Fra match without calling Sportradar live.

Non-negotiables:
- Missing data = "—", never guessed
- Every stat carries a source for the Sportradar ✓ badge
- get_historical MUST return null/empty if no pattern matches — Gemma 4
  will use that to trigger the trust-escape path, not fabricate

What's my first concrete task (≤2 hours)?
```

### FRONTEND / UI

```
BroadcastBrain YC Hackathon — Feature 2. Pull the latest main.

Read SPEC.md §Feature 2. Then open
frontend/design-handoff/feature-2/Feature 2 - Live Dashboard.html in a
browser to see the design render live.

My job: port right-pane.jsx components 1:1 to React Native TypeScript.
Start with LivePaneShell (the container), then the 3-card stack pattern
(CardStack + ScorerStatCard + PrecedentCard + CounterNarrativeCard), then
ambient widgets (RunningScorePanel + StoryQueue), then the voice UI
(BottomBezel + TranscriptOverlay + VoiceWidget). Tokens already in
app/src/theme/tokens.ts. Reuse shared primitives from
frontend/design-handoff/feature-1/frame.jsx — do not rebuild them.

Wire components to the Zustand event bus per DATA_CONTRACTS §3. Use mock
events from frontend/features/feature-2-live-copilot.md until backend
lands real match_cache.json output.

Non-negotiables:
- Every card shows "Sportradar ✓"
- iPadOS airplane-mode glyph visible in status bar on every screen
- Visual-first, silent by default — cards fade after ~8s if unused,
  never force modal attention
- IBM Plex Mono throughout
- No confidence-tier UI (no "~" prefix, no "medium" badge)

What's my first concrete task (≤2 hours)?
```

### CACTUS / GEMMA 4

```
BroadcastBrain YC Hackathon — Feature 2. Pull the latest main.

Read SPEC.md §Shared Architecture + §Feature 2, then
frontend/DATA_CONTRACTS.md §2 (function toolbox) and §3 (event bus) and
§5 (askGemma contract).

My job: wire askGemma to emit the correct Zustand event based on input
path and Gemma 4's intent classification:

Autonomous path (continuous audio buffer → stat-worthy event detected):
  → emit 3 events back-to-back: 'stat_card' + 'precedent' + 'counter_narrative'
  → plus 'running_score' on goals and 'streak_alert' when a pre-computed
     streak is at risk

Voice-commanded path (press-to-talk audio):
  → Gemma 4 classifies intent from the transcript:
     - COMMAND ("Show me X") → function-call (e.g. get_historical) →
       emit 'widget_built' with WidgetSpec
     - QUERY ("How does X") → function-call (e.g. get_player_stat) →
       emit 'answer_card'
     - UNGROUNDED → emit 'no_data' with the question text
  → MUST NEVER fabricate. If no function grounds the answer confidently,
     take the trust-escape path.

Critical first de-risker: is Cactus RN SDK's multimodal audio input
stable enough to classify COMMAND vs QUERY vs UNGROUNDED reliably from
short press-to-talk utterances? If not, we fall back to client-side
pattern matching on the transcript. Test this before wiring events.

What's my first concrete task (≤2 hours)?
```

---

## Why the "≤2-hour task" ending matters

Without it, a fresh Claude tends to scaffold endlessly — it produces a ten-step plan instead of shipping. That line forces it to pick the highest-leverage unblocker and start. Keep it in the prompt.
