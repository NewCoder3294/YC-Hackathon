# BroadcastBrain — Hackathon Spec v2 (Focused 3-Feature Build, Soccer Edition)

**Hackathon:** YC Voice Agents Hackathon 2026 · Cactus + Gemma 4 · April 18–19, 2026
**Team:** 4 generalists (no iOS) · **Budget:** ~22 hours
**Target tracks:** Best On-Device Enterprise Agent (B2B) + Deepest Technical Integration

This supersedes `SPEC.md` for the hackathon build. The v1 SPEC is the full vision; this is the focused 2-feature MVP we ship on the clock. (Collapsed from 3 features when it became clear that Feature 3 "Voice Query" was just the commentator-initiated entry point to Feature 2's Live Co-Pilot — same canvas, same Gemma 4 contract, same function toolbox.)

---

## Why this demo match

**Argentina vs France — 2022 FIFA World Cup Final · 18 December 2022 · Lusail Stadium, Qatar**

Picked deliberately for the demo:
- **Most-watched football match in history** (~1.5B viewers). Every judge has an opinion on it. Zero "what sport is this?" overhead.
- **Dense in stat-worthy moments** the product can surface: Messi's 23rd-minute penalty, Di María's 36th-minute finish, Mbappé's 80th + 81st-minute brace (the fastest two-minute two-goal brace in a final ever), Messi's extra-time goal, Mbappé's extra-time equaliser, the penalty shoot-out.
- **Pre-caching is trivial** — this match is over. Every stat exists, every broadcast call is on YouTube. Perfect for airplane-mode demo.
- **Peter Drury's Messi call** ("Lionel Messi ascends to football heaven...") is the single most recognisable football broadcast clip ever made. Using that as our live-pipeline input is both emotional and a clear "on-device transcription works" proof.

**Hero players for the demo:** Lionel Messi (Argentina #10), Kylian Mbappé (France #10). Both scored hat-tricks (Mbappé's was the first in a WC final since 1966). Every stat card either hero triggers will land with the room.

---

## Why iPad (not iPhone)

The broadcaster research explicitly pointed at **iPad in the booth**:

> Pat McCarthy (NY Mets): "broadcasters can view on tablet in booth" — his primary surface, not a phone.
> Bob Heussler (Brooklyn Nets): hand-draws boards on paper-sized sheets — an iPad replaces paper, not a phone.

**Design implications for iPad (landscape, 10.2"+ form factor):**
- Primary surface is a split layout: spotting board left, live dashboard right. No tab switching during a match.
- Larger stat cards — 2–3× the type size of a phone layout. Booth lighting is dim; peripheral-vision glanceability matters more than screen real-estate economy.
- Voice query button lives along the bottom bezel of the screen — natural thumb reach when the iPad is resting on a desk/booth shelf.
- Running score tracker, story reminder queue, and streak alerts can live *in-frame* alongside the primary stat card (on iPhone they'd need to hide/collapse).

**Demo device:** physical iPad (Pro preferred, Air fine). Mirrored to stage screen via AirPlay or USB-C. Airplane mode on from second 0.

---

## What we're building

A voice-powered AI employee for sports broadcasters. Listens to the match, knows every player, surfaces the right stat the instant it's relevant, and answers any question on demand — all on-device, airplane-mode-safe. Validated with 4 working broadcasters (Brooklyn Nets, NY Mets, CBS Sports Radio, local markets).

**Research honesty:** those 4 broadcasters are MLB / NBA / hockey / multi-sport radio. None was a dedicated soccer commentator. The generic pain pattern (25% of prep used, handwritten spotting boards, accuracy paranoia, visual-first non-intrusive surface) validated across all four. **Pitch response when asked:** *"We validated the problem pattern across MLB, NBA, and hockey broadcasting. We chose the 2022 World Cup Final as the demo because it's the most-watched match in history — every judge can read it instantly. The soccer expansion is the next interview batch, not the pitch."*

---

## The 2 Features

### Feature 1 — Pre-match Auto Spotting Board *(the wedge, validated by all 4 interviews)*

Broadcasters spend hours — sometimes days — hand-building a "spotting board" before every match. They use ~25% of it. BroadcastBrain builds the full board automatically overnight, from the football stats APIs, formatted exactly how a broadcaster would lay it out.

**Research anchors:**
- Bob Heussler: "spends hours creating detailed handwritten charts, numerical charts, and storyline outlines for every player"
- Rich Ackerman: "strongly believes in conducting his own research and creating his own spotting boards"
- Pat McCarthy: mix of own research + network-provided research teams; uses ChatGPT for prep
- Trey Redfield: broadcasters "only use about 25% of their notes" — the stat that powers the whole pitch

**UX (iPad, landscape):**
- Open app → home shows the match card (**Argentina vs France · 18 Dec 2022 · Lusail Stadium · FIFA World Cup Final**). Tap.
- Split layout loads instantly: Argentina left (light blue/white header), France right (navy header), 23-player squads each side.
- Each player card: portrait headshot, **#10 · FW · Lionel Messi (ARG)**, three stat lines for the tournament (goals, assists, xG), one storyline ("*Seeking his first World Cup trophy at age 35, last dance*"), one matchup note ("*Has scored in every knockout round this tournament*"). Every stat shows a `Sportradar ✓` source badge.
- Tap a player card → full player profile takes over: tournament-wide stats, career stats, last-5-matches form, head-to-head vs specific France defenders.
- **Edit board:** long-press a stat → replace from alternatives; tap-to-pin keeps a specific stat pinned. Preferences persist per team.
- **Export PDF:** paper backup for the booth in case the device dies.
- **Works in airplane mode from load onward** — all data is cached locally at match start.

**Data flow:**
```
Overnight (T-12hrs):
  Stats API (Sportradar Soccer / FIFA data)
    ↓ squads, tournament stats, match history, news, injuries
  Gemma 4 (on-device, one call per player)
    ↓ generates { top_stats, storyline, matchup_note }
  Bundled into app → opens offline
```

**Gemma 4 prompt (per player, inherit shape from SPEC.md §1.0):**
```
You are building a broadcaster's spotting board entry for {player_name} ({position}) ahead
of the 2022 FIFA World Cup Final.

Tournament stats: {tournament_stats_json}
Career stats: {career_stats_json}
Matchup: {opposing_nation}, likely opposing defenders/attackers: {matchup_players}

Generate JSON only:
{
  "top_stats": [ "stat line 1", "stat line 2", "stat line 3" ],
  "storyline": "one sentence — narrative arc, milestone, or current form",
  "matchup_note": "one sentence — performance vs today's opponent or head-to-head"
}

Rules: concise, broadcaster-ready. Every stat must come from the payload, not invention.
If a field is missing, output "—".
```

**Accuracy rule:** if the stats payload is missing a field, the card shows `—`, not a guess. Every stat in the UI shows its source. One fabricated stat ends a broadcaster's career — this is non-negotiable.

**Scope this hackathon:** one match (Argentina vs France 2022 Final). 46 players total (23 + 23). All data bundled in app.

---

### Feature 2 — Live Co-Pilot *(always-on autonomous + voice-commanded, validated by Pat + Trey)*

**Feature 2 is the always-on co-pilot during the match.** Two input modes, one shared canvas:

1. **Autonomous (AI-initiated).** The iPad listens continuously; when something stat-worthy happens, the AI autonomously surfaces cards and updates ambient widgets (running score, xG ticker, story queue, streak alerts). Broadcaster is passive — glance, use or ignore, move on.
2. **Voice-commanded (commentator-initiated, press-to-talk).** One button; works any time. Gemma 4 auto-routes phrasing:
   - *"Show me / Pull up / Track …"* → **COMMAND** → widget materializes on the Live Pane (pinnable).
   - *"How does / What's / Compare …"* → **QUERY** → sourced answer card + (if opt-in) TTS.
   - Not grounded in verified data → **TRUST ESCAPE**: *"I don't have verified data on that."*

Both input modes use the same `askGemma` contract, the same Gemma 4 function toolbox, and render into the same Live Pane. The split is just *who initiated*. See `frontend/DATA_CONTRACTS.md §3` for the Zustand event types: autonomous surfaces emit `stat_card` / `precedent` / `counter_narrative` / `running_score`; commentator-initiated surfaces emit `widget_built` / `answer_card` / `no_data`.

During the match the iPad listens continuously. When something stat-worthy happens, a card appears on screen — non-intrusive, never audio. Broadcaster glances, decides whether to use it, carries on.

**Research anchors:**
- Pat McCarthy: wary of voice agents during live games, *"fearing sensory overload"* → the whisper is visual-only by design
- Pat: play-by-play is "off the cuff" → the AI must never interrupt
- Trey Redfield: tech should help broadcasters "think faster and access 'dynamic' storylines in real-time"

**Soccer-specific event triggers** (continuous flow, not discrete plays like baseball):
- **Goal** — highest-priority card: scorer season stats + tournament stats + historical comparison
- **Shot on target / big chance** — shooter's tournament shot conversion, xG
- **Key pass / assist** — creator's chance-creation stats for the tournament
- **Foul / yellow / red** — card context, player discipline record
- **Substitution** — incoming player's tournament impact stats
- **Corner / set-piece** — team set-piece conversion rate this tournament
- **VAR review** — pause the whisper during review, resume when result is confirmed
- **Half-time / full-time / extra-time / shoot-out transitions** — narrative recap cards

**UX (iPad, split panel — always visible alongside spotting board):**
- iPad sits on the desk, landscape, in peripheral vision. Broadcaster is talking continuously.
- Messi scores the 23rd-minute penalty. Broadcaster calls the goal.
- ~800ms later: **soft orange dot pulses top-right of the Live panel.** No sound.
- Stat card animates into the Live panel:
  ```
  ⚽ MESSI
  23' PEN · 1-0 ARGENTINA
  6th goal of tournament · 2nd WC Final goal of career
  1st player to score in every WC knockout round (group, R16, QF, SF, Final)
  Sportradar ✓                  [842ms]
  ```
- Broadcaster finishes sentence, glances, reads it naturally into his next beat.
- Card stays visible 8 seconds then fades. If not used, it's gone — no dismissal required.
- Next event triggers a new card. One card at a time; newer supersedes an unused older one.
- **Dup suppression:** Gemma 4's own STT hears the broadcaster's speech; if the stat was already spoken on air, don't re-surface.
- **Latency counter** visible in demo mode (tiny, bottom-right corner). Hidden in prod.

**Data flow (fully on-device via Gemma 4 multimodal):**
```
iPad mic (expo-av, 2s rolling window)
    ↓ audio chunk
Gemma 4 multimodal (Cactus, on-device) — ONE CALL:
    • transcribes audio (native multimodal)
    • extracts structured context (player, event, situation)
    • decides stat_opportunity
    • function-calls get_player_stat(player, situation) against local cache
    • generates final stat_text with source
    ↓
Event bus → Live panel renders card
```

**Why one Gemma 4 call instead of Whisper → LLM:** Gemma 4 on Cactus is multimodal (voice in, function calling, structured output, native). This eliminates an entire layer (no separate Whisper), lowers latency, and is exactly the technical integration Cactus/DeepMind judges want to see demoed.

**Gemma 4 function signatures (soccer-shaped):**
```ts
get_player_stat(player_name: string, situation: string)
  → { stat_text, stat_value, source: "Sportradar", confidence: "high"|"medium" }

get_team_stat(team: string, metric: string)        // possession, xG, set-piece %, etc.
get_match_context(match_id: string)                // live score, minute, booking count
get_historical(player: string, comparison: string) // career records, WC-specific splits
```
All resolved against pre-cached `match_cache.json` — zero network calls during the live demo.

**Routing:** simple stat lookups → Gemma 4 on-device end-to-end. Complex historical comparisons (e.g., *"most goals in a WC final since 1966"*) → Cactus hybrid routes to Gemini. Routing decision is emitted by Gemma 4 itself via a `query_complexity: "simple"|"complex"` field. Demo must work airplane-mode, so demo path is simple.

**Latency budget (realistic on-device, RN + Cactus on iPad):**

| Stage | Target |
|-------|--------|
| Audio buffer fill | ~500ms |
| Gemma 4 multimodal (STT + extract + function call + generate) | ~400ms |
| Dashboard render | ~50ms |
| **Total** | **~950ms** |

SPEC v1 quoted 200ms — that was native iOS with a separate Whisper model. Realistic for this stack is **~1 second**. Still comfortably inside the soccer "eventful moment → next touch" window. Show the real number in the demo; be honest.

**Proactive features (add if hours 12–18 allow):**
- **Live xG ticker** *(adapt from Bob Heussler's "running score tracker" ask)*: xG-for / xG-against drifting as the match progresses. A goal's xG value animates onto the ticker when scored.
- **Streak / milestone alerts** *(Trey Redfield)*: Messi's *"score in every knockout round"* streak pre-computed; if he's gone through a round without scoring, flag visually as at risk.
- **Story reminder queue** *(Rich Ackerman)*: side panel of broadcaster's pre-planned storylines ("Messi's 5th WC — last dance", "Mbappé chasing Golden Boot"); STT detects which have been mentioned, surfaces unmentioned during lulls. Directly ties the *"25% of prep"* stat into the product.

These are bonus. Don't add until Feature 2 base works end-to-end.

**Voice-commanded UX — press-to-talk flow:**
- Big press-to-talk button anchored along the bottom bezel of the iPad, both-thumbs-reach. No wake word (wake words cause accidental triggers mid-call — validated concern).
- User presses and holds → soft *"ding"* → screen shows **"Listening…"** with a waveform animation filling the centre of the Live Pane.
- Speaks: *"How many goals has Mbappé scored in World Cups?"*
- Releases button (or 8-second auto-cutoff).
- **"Thinking…"** shimmer (~1.5s) while Gemma 4 transcribes + function-calls the local data.
- Answer card appears on the Live Pane **and** plays through bluetooth earpiece if opt-in TTS is enabled:
  ```
  🎤 "How many goals has Mbappé scored in World Cups?"

  Mbappé career WC goals: 12
  Youngest player to reach 10 WC goals since Pelé
  Qatar 2022: 8 goals · leading Golden Boot
  Sportradar ✓                        [1.4s]
  ```
- If Gemma 4 can't ground the answer (e.g., *"what's his favourite food?"*), the app responds: **"I don't have verified data on that."** This is a *trust feature*, not a failure mode. Validated by Bob Heussler's "devil's advocate on accuracy" concern — a broadcaster would rather hear "I don't know" than a confident wrong answer.

**Voice-command routing (Gemma 4 decides by phrasing):**
```
Button press → audio capture (expo-av, up to 8s)
    ↓
Gemma 4 multimodal (Cactus): transcribe → classify intent
    ↓
  ┌── COMMAND ("Show me...") → function-calls → widget_built event → Live Pane widget
  ├── QUERY   ("How does...") → function-calls → answer_card event → Live Pane card + TTS
  └── UNGROUNDED              → no_data event  → Live Pane trust-escape card
```
All three paths share the same function toolbox as autonomous surfaces. No live network calls during the demo.

**Voice-mode target persona (research honesty):**
- None of the four interviewees are soccer broadcasters or colour commentators. The "voice-first, has natural dead air" persona is *inferred*.
- Pat McCarthy explicitly *did not want* voice prompting mid-call for himself.
- Pat's own insight: *"the tool may be even more immediately effective for the statistician at the table than for the on-air talent directly."*
- **Pitch framing:** lead with Pat's statistician-angle quote. Frame voice commands as the tool the *statistician / analyst* uses to serve the on-air talent at 10× speed. Don't oversell as "every broadcaster wants this" — that's not what the research shows.

---

## Shared Architecture

```
┌─ iPad (React Native + Expo) ────────────────────────────────────────┐
│                                                                      │
│  UI (React Native, landscape-primary, split-pane)                   │
│    ├─ SpottingBoardPane (left ~60%) ← Feature 1                     │
│    └─ LiveDashboardPane (right ~40%) ← Feature 2               │
│                                                                      │
│  State (Zustand event bus)                                          │
│    ├─ stat_card, transcript, context  (emitted by pipeline)         │
│    └─ voice_query, opt_in_tts         (emitted by UI)               │
│                                                                      │
│  Pipeline                                                            │
│    ├─ AudioCapture (expo-av, rolling 2s + press-to-talk)            │
│    └─ askGemma(input, context, routing) ──────┐                     │
│                                                ↓                     │
│  Cactus RN SDK ──► Gemma 4 on-device (multimodal)                   │
│                       • STT                                          │
│                       • context extraction                           │
│                       • function calling                             │
│                       • text generation                              │
│                       • optional routing → Gemini (cloud)            │
│                                                                      │
│  Data                                                                │
│    └─ assets/match_cache.json (pre-fetched Arg vs Fra 2022 bundle)  │
│                                                                      │
│  TTS: expo-speech (opt-in only, voice-command path)                 │
└──────────────────────────────────────────────────────────────────────┘
```

**Single integration contract** (both features call this):
```ts
askGemma(input: { prompt?: string, audio?: ArrayBuffer }, context: object, routing: 'auto'|'local'|'cloud')
  → Promise<{
      stat_text: string,
      source: string,
      confidence: 'high' | 'medium',
      player?: string,
      latency_ms: number,
      transcript?: string,    // voice-command path: what the user said
    }>
```

**Stack fallback** (if Cactus RN binding doesn't expose Gemma 4 multimodal in the JS layer in time): wrap the Cactus native iPadOS SDK in an Expo config plugin + thin native module. One person owns this. Resolved in the Sprint 0 pre-work spike.

---

## Shared UX Rules (apply to both features)

1. **Source citation is non-negotiable.** Every stat shows `Sportradar ✓`. If data is unavailable, `—` not a guess.
2. **Confidence markers.** `high` renders normally. `medium` gets a `~` prefix and is **never spoken** via TTS.
3. **Airplane mode from demo second 0.** Both features work offline because the match data is bundled. Only cloud routing (Gemini for complex historical queries) needs network, and we route around that for the demo.
4. **Latency counter visible only in demo mode.** Bottom-right corner, tiny. Real measured ms. Real numbers beat marketed numbers with YC partners.
5. **One-handed, peripheral-vision-friendly type.** Booth lighting is dim. The iPad competes with a paper team-sheet and a scoreboard.
6. **Never interrupt the call.** Visual-first, silent. Voice output only when explicitly opted in via button. Pat McCarthy's validated constraint.
7. **The broadcaster stays in control.** The AI surfaces, the broadcaster decides. Never auto-posts, auto-speaks, auto-anything.

---

## What we're NOT building

Explicitly deferred from SPEC v1, don't touch unless hours 18–20 are uneventful:

- Phase 2 OBS graphics overlay trigger
- Phase 2 viral clip flagging
- Phase 2 replay director cueing
- Director dashboard
- Multi-sport (MLB, NBA, NFL) — soccer only, one match
- Multi-match (other World Cup matches, Premier League games) — Argentina vs France 2022 only
- Wake word activation — button-press only
- Matchup-to-matchup memory (Phase 3 roadmap)
- Any feature not directly demoable in the 5-minute stage demo

---

## Demo Script (5 minutes, tight)

**Setup:** iPad on stage stand, mirrored to big screen. **Airplane mode on, visible in status bar from second 0.**

| Time | Beat |
|------|------|
| 0:00–0:30 | Problem + research. "Broadcasters spend hours on prep, use 25%. We talked to 4 of them — NY Mets, Brooklyn Nets, CBS Sports Radio, local markets. Every one of them hand-builds a spotting board." Show one Pat McCarthy quote on screen. |
| 0:30–1:30 | **Feature 1.** Open the pre-built spotting board for Argentina vs France 2022. Scroll Messi's card — tournament stats, storyline ("Seeking his first World Cup at 35"), matchup note. Tap-expand to full profile. "This took zero minutes. Built overnight. Gemma 4 on Cactus, on-device." |
| 1:30–3:00 | **Feature 2 — money shot.** Play the Peter Drury audio from Messi's 23rd-minute penalty (*"Argentina are ahead…"*). ~1 second later, stat card lands: *"6th of tournament · 1st player to score in every WC knockout round."* Latency counter visible. "Gemma 4 multimodal — audio in, function-calls local data, stat out. No internet. This is airplane mode." Then play Mbappé's 80th-minute strike — another card, another real number on the counter. |
| 3:00–4:00 | **Feature 2 — voice-commanded beat.** Press the voice button. *"How many goals has Mbappé scored in World Cups?"* Answer on screen + spoken in ~1.5s. Follow up with *"Show me every Argentine penalty in WC finals"* → widget materializes on the Live Pane. Follow with *"What about his favourite food?"* → *"I don't have verified data on that."* "Statistician's new best friend. Same co-pilot, two input modes — we listen, we answer, we refuse to guess." |
| 4:00–5:00 | Pitch close. "Broadcasters today. Live field reporters next. Every professional who needs the right context in the moment after that. The on-device story isn't a feature — it's the latency and trust requirement. Kill-the-WiFi is our moat." |

**Three things judges will remember:**
1. Airplane-mode indicator on the iPad status bar the entire demo.
2. Latency counter showing a real sub-1-second number.
3. The Messi audio + the stat card landing beat the audio's reverb decay.

---

## File Structure

```
broadcastbrain/
├── app.json                         # Expo config, Cactus native plugin, iPad primary
├── assets/
│   └── match_cache.json             # Pre-fetched Arg vs Fra 2022 Final bundle
├── src/
│   ├── cactus/
│   │   ├── askGemma.ts              # The single integration contract
│   │   ├── prompts.ts               # Inherited from SPEC.md §1.0, §1.3, §1.5
│   │   ├── functions.ts             # get_player_stat, get_team_stat, ...
│   │   └── native/                  # Native module glue (Expo config plugin)
│   ├── data/
│   │   ├── sportradar.ts            # Overnight fetcher (Node script, runs once)
│   │   └── spottingBoard.ts         # Feature 1 pipeline
│   ├── audio/
│   │   └── capture.ts               # expo-av rolling + press-to-talk
│   ├── pipeline.ts                  # Orchestrator: audio → askGemma → event bus
│   ├── screens/
│   │   └── MatchScreen.tsx          # Single split-pane iPad landscape screen
│   ├── panes/
│   │   ├── SpottingBoardPane.tsx    # Feature 1 UI (left ~60%)
│   │   └── LiveDashboardPane.tsx    # Feature 2 UI (right ~40%)
│   ├── components/
│   │   ├── PlayerCard.tsx
│   │   ├── LiveStatCard.tsx
│   │   ├── FlashingCue.tsx
│   │   ├── VoiceQueryButton.tsx
│   │   ├── AnswerCard.tsx
│   │   └── LatencyCounter.tsx       # demo mode only
│   └── state/events.ts              # Zustand event bus
├── SPEC.md                          # v1 — full vision
└── SPEC_v2.md                       # this file — hackathon build
```

---

## Success Criteria

- Feature 1: opens on iPad in airplane mode, shows both 23-player squads with stats + storylines + source badges, split landscape layout.
- Feature 2: 30s Peter Drury clip of Messi's 23rd-minute penalty → stat card on right panel with measured latency < 1.5s, `Sportradar ✓` cited.
- Feature 2 voice-commanded path: button press → voice question → sourced answer on right panel + spoken aloud in < 2s; button press → voice command ("show me X") → widget materializes on right panel. Knows when to say "I don't have verified data on that."
- Entire demo runs on the iPad in airplane mode, no cables to a laptop, no fallback.
- Backup demo video recorded by hour 20 as insurance.

---

## Open Questions for Pre-Kickoff (Sprint 0)

1. Cactus RN SDK — does it expose Gemma 4 multimodal audio input directly on iPad running Expo? **Spike this first.** If not, need the Expo config plugin + native module route.
2. Which Sportradar / football data endpoints hold archived 2022 World Cup match data? Alternate source: StatsBomb Open Data (free, detailed event data for this match specifically).
3. Hardware button for Feature 2 voice command path — on-screen bottom-bezel button only, or optional external puck (Flic)? Recommend on-screen only for demo simplicity.
4. Who is the dedicated "prompt tuner" in Track A — the prompts in SPEC.md §1.0, §1.3, §1.5 are v1 and will need 2–3 hours of iteration against the real Peter Drury audio fixtures.
5. Which 3–4 audio clips (goals / key moments) do we bundle as live-pipeline fixtures? Candidates: Messi's 23rd-min pen, Di María's 36th-min finish, Mbappé's 80th+81st brace, Messi's extra-time goal, the penalty shoot-out sequence.
