# Voice Pipeline — Design Spec

**Project:** BroadcastBrain · YC Voice Agents Hackathon 2026
**Scope:** Feature 2 voice/Gemma 4/Cactus pipeline (the "backend" of the on-device app)
**Track owner:** CACTUS/GEMMA 4
**Date:** 2026-04-18
**Parallel agents:** FRONTEND/UI (porting right-pane components), DATA (seeding `match_cache.json`)

Supersedes the voice-related sections of `FEATURE_2_PICKUP.md §CACTUS / GEMMA 4` with concrete module layout and contracts.

---

## 1. Goal

Ship the on-device voice pipeline that powers Feature 2 (Live Co-Pilot). Two input modes, one shared contract:

- **Autonomous** — continuous audio capture, stat-worthy events auto-surface as `stat_card` + `precedent` + `counter_narrative` events on a Zustand event bus.
- **Voice-commanded** — press-to-talk button records an utterance, Gemma 4 classifies intent (COMMAND / QUERY / UNGROUNDED), emits `widget_built` / `answer_card` / `no_data`.

All on-device, airplane-mode-safe, zero fabrication. Runs on an M-series iPad via Cactus RN SDK + Gemma 4 multimodal.

## 2. Non-goals

- Cloud routing (`routing: 'cloud'`) — deferred post-demo.
- Commentator-profile learning loop (stat-swap history ranker). Profile is read-only this hackathon.
- Multi-match, multi-sport, wake words, external voice hardware.
- Thermal endurance past the 5-minute demo.

## 3. Architecture

One module owns the entire voice stack and exposes a single public contract.

```
app/src/cactus/
├── askGemma.ts                     THE single integration contract (DATA_CONTRACTS §5)
├── client.ts                       Cactus RN SDK wrapper: loadModel, generate, closeModel
├── prompts.ts                      System prompts per path (autonomous / query / command)
├── functions.ts                    Gemma 4 function toolbox bound to matchCache
├── audio/
│   ├── continuous.ts               Rolling-window capture (expo-av metering + VAD)
│   └── pressToTalk.ts              Gated capture (onPressIn → onPressOut)
├── pipeline/
│   ├── orchestrator.ts             Glues capture → askGemma → event bus
│   ├── gate.ts                     stat_opportunity + VAD + dedupe
│   └── dedupe.ts                   Rolling transcript / signature cache
└── state/
    ├── eventBus.ts                 Typed Zustand store (DATA_CONTRACTS §3)
    └── matchCache.ts               Loads match_cache.json once, in-memory
```

**Ownership rule:** nothing outside `app/src/cactus/` touches Cactus, `expo-av`, or `expo-speech`. Other tracks interact only via `askGemma`, the event bus, and `matchCache`.

## 4. Data flow

### 4.1 Continuous (autonomous) hot loop

```
expo-av recording (2s rolling window, 500ms overlap, metering on)
    │
    ├── VAD gate (peak_dB < -40 OR voiced_frames < 8 of 20) ── drop
    │
    ▼
askGemma({ audio: chunk }, context, 'local')
    │
    ▼
Gemma 4 multimodal · AUTONOMOUS prompt
    returns JSON: { transcript, stat_opportunity, event_type?, players_mentioned?, score_state_changed? }
    │
    ├── stat_opportunity=false ── emit 'transcript', drop
    │
    ▼
Dedupe (stat signature in last 30s of surfaces? OR commentator already said it in last 20s?) ── drop if yes
    │
    ▼
Second Gemma 4 call: function phase
    available functions: get_player_stat, get_team_stat, get_match_context, get_historical
    Gemma 4 picks functions, orchestrator executes locally, feeds results back, Gemma 4 generates final card
    │
    ▼
Orchestrator emits 3 events:
    · stat_card          { player_id, stat_text, source, latency_ms, confidence_high }
    · precedent          { pattern_id, stat_text, category }
    · counter_narrative  { text, for_team, tone }
```

**Cost model:** cheap first call runs on every voiced chunk (~150–250ms). Expensive second call runs only when the gate passes (~1-in-N chunks in real commentary). Keeps thermal sane.

### 4.2 Press-to-talk (voice-commanded)

```
User holds bezel button (LivePaneShell.VoiceBezel)
    │
    ▼
expo-av single recording (start on onPressIn, stop on onPressOut, 8s max)
    │
    ▼
askGemma({ audio: recording }, context, 'local')
    Gemma 4 multimodal · QUERY_OR_COMMAND prompt
    transcribes + classifies intent
    │
    ├── COMMAND   → function-calls → widget spec → emit 'widget_built'
    ├── QUERY     → function-calls → answer     → emit 'answer_card' (+ opt-in TTS via expo-speech)
    └── UNGROUNDED → emit 'no_data' with the question text
```

Both paths share: matchCache, function toolbox, event bus, latency timer, grounding discipline. Only difference: system prompt and events emitted.

## 5. Gate and dedupe

Three filters, cheapest first.

**VAD (JS thread, free):** `chunk_is_voiced = peak_dB > -40 AND voiced_frames >= 8 of 20`. Drops silence and room tone before any Gemma call.

**Opportunity classifier (first Gemma call, ~150–250ms):** system prompt returns JSON only, and `stat_opportunity=true` only when the commentator described a *discrete stat-worthy event in this chunk* (goal, shot on target, card, sub, milestone). Ambient analysis and filler = false.

**Dedupe (pre-generate):**
- `stat_signature = hash(event_type + players_mentioned.sort())`
- If signature in `recently_surfaced_signatures` (last 30s), drop.
- If candidate stat already matches a substring in `rolling_transcript` (last 20s of commentator speech), drop. (SPEC §Feature 2 dup-suppression rule.)

**Back-pressure:** orchestrator holds at most one in-flight inference. Newer chunk arriving during in-flight → cancel old via `AbortSignal`, newest wins.

**Emergency valve:** 3 consecutive chunks miss 1500ms budget → fall to slower cadence (3s windows, 500ms cooldown). Silent diagnostic event, not user-visible.

## 6. Function toolbox (grounding)

All pure reads against in-memory `matchCache.json`. Zero network. Every return carries `source` or returns `null`.

```ts
get_player_stat(player_name: string, situation?: string)
  → { stat_text, value, source, confidence_high } | null

get_team_stat(team: 'arg'|'fra', metric: string)
  → { stat_text, value, source, confidence_high } | null

get_match_context(match_id: string)
  → { score, minute, added_time, phase, possession_pct, shots, recent_events }

get_historical(query: string)
  → PrecedentPattern[]    // empty array if no match — never fabricated

get_commentator_profile()
  → CommentatorProfile    // AsyncStorage-backed with sane defaults
```

Shapes match `DATA_CONTRACTS.md §2` exactly.

**Three grounding rules:**

1. Every function returns a `source` or `null`. If `matchCache` doesn't contain the stat, return `null` — never synthesize.
2. `confidence_high` is derived, not asserted. Direct lookup → `true`. Computed/derived → `false`. Caller uses this to gate TTS.
3. Function throws → orchestrator catches and emits `{ type: 'no_data', question }`. Never fabricates a card.

**Player-name resolution:** case-insensitive token-overlap against all 46 `player.name` values. Falls back to last name, shirt number, `role_tags` synonyms ("the captain", "the 10"). If ≥ 2 matches tie → return `null` (ambiguous → trust escape).

**Precedent matching:** `get_historical(query)` matches the current match state against each `PrecedentPattern.trigger` shape (event_type + minute_range + score_state + player_filters). Returns all eligible patterns; orchestrator picks highest category priority.

**System prompt (enforced at the prompt layer):**

```
RULES:
1. Call functions. Do not invent stats.
2. If a function returns null or an empty array, emit trust_escape. Do not guess.
3. Every stat_text you generate must be grounded in a value you received from a function in THIS session.
4. If the player name is ambiguous, emit trust_escape.
```

## 7. Error handling and airplane-mode guarantees

| Path | Network? | On network loss |
|------|----------|-----------------|
| `askGemma` · `routing: 'local'` | Never | Unchanged |
| `askGemma` · `routing: 'cloud'` | Gemini fallback | Caught, falls to `local`, `no_data` if ungroundable |
| `matchCache` load | Bundled asset | Never network |
| Cactus model load | Local file (install-time download) | Never network |
| TTS (`expo-speech`) | On-device voices | Offline |

`askGemma` probes `NetInfo.isConnected` before any `'cloud'` route. Demo always runs `'local'`.

### Failure modes

| Failure | Response |
|---------|----------|
| Cactus model fails to load at startup | Emit `model_unavailable`; bezel disabled with "VOICE OFFLINE"; continuous loop never starts |
| `expo-av` permission denied | Same as above; surface a permissions prompt once |
| Single inference > 3s | `AbortSignal` cancel, drop chunk silently, tick diagnostic counter |
| 3 consecutive timeouts | Fall to slower cadence (§5 emergency valve) |
| Function throws | Catch, emit `no_data`, silent log |
| Gemma 4 returns malformed JSON | Retry once with stricter prompt; second failure → drop silently |
| `matchCache` load fails | Hard failure, diagnostic screen (build-time bundling issue) |

No toast spam. AI fails silently or via `no_data`. Never a fabricated card.

## 8. Integration seams

**FRONTEND/UI consumes (no emission into Cactus internals):**

```ts
import { useEventBus } from 'app/src/cactus/state/eventBus'
const statCard = useEventBus(s => s.latest('stat_card'))
```

All 14 event types are defined in `DATA_CONTRACTS.md §3` and typed at the boundary.

**DATA/BACKEND produces:**

```
app/assets/match_cache.json    per DATA_CONTRACTS §1
```

`matchCache.ts` loads this file, validates against a `zod` schema, and holds it read-only in memory. Schema mismatch fails loudly at app startup — not silently at demo time. A partial cache (Messi + Mbappé + 4 demo beats) is enough to unblock this track.

**This track produces:**

- `askGemma(input, context, routing)` — single public contract, matching `DATA_CONTRACTS §5` exactly.
- Typed event bus with all 14 event shapes populated.
- Rewiring `AgentProvider` to subscribe to the bus (replaces the current `DEMO_POINTS` timer rotation; one-file change).

No circular dependencies, no cross-module reach. Every agent can work without blocking on the others as long as DATA_CONTRACTS shapes hold.

## 9. Testing

**Layer 1 — Unit, no device (Jest + `@testing-library/react-native`):**
- `functions.ts`: every function returns source or null; ambiguous name → null; missing key → null.
- `gate.ts`: VAD reject / opportunity reject / dedupe reject / pass cases.
- `dedupe.ts`: commentator said it 8s ago → drop; novel stat → pass.
- `eventBus.ts`: type discipline at compile time; unknown event types rejected.

**Layer 2 — Cactus-in-the-loop smoke (Node harness):**

`scripts/cactus-smoke.ts` runs Cactus Python CLI directly on bundled WAV fixtures (`app/assets/audio-fixtures/`: Messi pen, Di María, Mbappé pen, Mbappé open-play). Prints transcript + classifier JSON + function calls + final card. Validates prompts + functions + matchCache without RN or iPad. Prompt-tuning loop lives here.

**Layer 3 — On-device smoke (iPad, manual):**

Hidden dev screen (`?devtools` query param) exposes:
- Start/stop continuous loop
- Fire fake `audio` input from bundled WAV
- Live latency counter per stage (VAD, classify, dedupe, function, generate)
- Event bus inspector (last 20 events)

Used for rehearsal.

### Acceptance

1. `npm test` green (Layer 1).
2. `scripts/cactus-smoke.ts` prints expected card on 4/4 demo clips (Layer 2).
3. iPad airplane-mode: hold bezel, ask *"how many goals has Mbappé scored in World Cups"* → sourced answer card in ≤ 2s.
4. iPad airplane-mode: play Peter Drury Messi-penalty clip into device mic → stat card appears in ≤ 1.5s.

### Not tested (explicitly)

- Gemma 4 prompt quality across edge cases (prompt-tuner's job, uses Layer 2).
- Thermal sustainability past 5 minutes.
- Cloud routing.

## 10. Dependencies to install

- `cactus-react-native` (or the current Cactus RN SDK name; resolve during Sprint-0 spike per SPEC Open Q1)
- `expo-av` — audio capture with metering
- `expo-speech` — opt-in TTS on the voice-commanded path
- `zod` — `matchCache` runtime validation at load

Native build implication: Cactus RN likely needs an Expo config plugin. If the Expo Go client can't load it, we switch to a custom dev client (`npx expo prebuild` + `eas build --profile development`). This is resolved on day 1 during the SDK spike.

## 11. Open questions (to resolve during implementation)

1. Does Cactus RN expose Gemma 4 multimodal audio directly in JS? If not, the config-plugin path is already in the design but adds ~4 hours of native bridging.
2. Does Cactus RN support `AbortSignal` on in-flight inferences? If not, we emulate via a queue with sequence numbers; next inference waits for current to finish or a 3s timeout.
3. `expo-av` metering fidelity on iPad for VAD — may need to be coarser (50ms samples) if the API doesn't give tighter resolution.

These are implementation-time questions, not blockers for the design.
