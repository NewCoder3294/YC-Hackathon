# BroadcastBrain — Technical Spec
**Hackathon: YC Voice Agents Hackathon 2026 (Cactus + Gemma 4)**
**Team size:** 4 | **Duration:** ~22 hours

---

## Problem

Sports broadcasters spend hours — sometimes days — building spotting boards before a single game. They use about 25% of what they prepare. The other 75% is the right stat at the wrong time: fully researched, never surfaced.

During the game, they have a 4-second window after every play to say something brilliant. The stats exist. The spotting board exists. But finding the right row, the right number, in that 4-second window — that's the gap.

No product today auto-builds the spotting board or surfaces the right stat at the right moment without requiring the broadcaster to interrupt their flow and query something.

We're building the AI that fills that gap — before the game and during it.

**Validated with 4 working broadcasters (Brooklyn Nets, NY Mets, CBS Sports Radio, local markets).**

---

## User Personas (from broadcaster research)

| Persona | Who | Primary use mode | Key need |
|---------|-----|-----------------|----------|
| **Play-by-play announcer** | Pat McCarthy (Mets), Bob Heussler (Nets), Rich Ackerman (WFAN) | Visual dashboard, opt-in voice during breaks | Non-intrusive stat surface; never interrupts the call |
| **Color commentator** | Analyst sitting next to play-by-play | Voice-first (natural dead air to fill), visual bonus | Quick answer to "what's his number on X" mid-analysis |
| **Statistician / researcher** | Sits at the table, filters info for on-air talent | Dashboard + voice query tool | High-speed research assistant — surfaces what the talent needs before they ask |
| **Local market / freelance** | One-person crew, no research staff (280+ college programs) | Full suite, no human backup | Replaces the research team they can't afford |

**Pat McCarthy's insight:** The tool may be even more immediately effective for the statistician at the table than for the on-air talent directly. The statistician is already the information filter — BroadcastBrain makes them 10x faster.

---

## Design Principles (from broadcaster research)

1. **The broadcaster stays in control.** AI never proactively interrupts. It surfaces information — the broadcaster decides what to use and when.
2. **Visual-first.** Play-by-play announcers are talking non-stop. A visual dashboard is always-on and never intrusive. Voice is opt-in.
3. **Accuracy over volume.** Stats must be sourced from verified APIs (Sportradar), not generated. A wrong stat on live radio is career-damaging. Always show the source.
4. **Fit the existing workflow.** Broadcasters already have spotting boards, handwritten charts, prep routines. BroadcastBrain should feel like their board got built for them — not a new system to learn.
5. **Role-aware.** Play-by-play announcers: visual dashboard primary, voice during breaks. Color commentators: voice-first is natural, visual is a bonus.

---

## Core Architecture

```
PRE-GAME (overnight)
  Sportradar API → Gemma 4 → Auto-built Spotting Board (visual)

LIVE GAME
Broadcast Audio
      │
      ▼
  STT (Whisper) — on-device
      │
      ▼
  Gemma 4 (via Cactus) — context extraction
      │
      ├──[simple]──→ Gemma 4 stat selection ──→ Visual Dashboard (primary)
      │                                     └──→ TTS → Earpiece (opt-in only)
      │
      └──[complex]──→ Gemini (via Cactus hybrid routing) ──→ Visual Dashboard
                              ↑                         └──→ TTS → Earpiece (opt-in)
                    Sportradar API (stats data, source-cited)
```

**Primary surface:** Visual dashboard — always on, non-intrusive, broadcaster glances at it when ready.
**Secondary surface:** Opt-in voice — broadcaster presses a button, asks a question, gets an instant answer.
**No proactive earpiece whispers.** Validated feedback: play-by-play announcers find unsolicited audio during live calls causes sensory overload.

**Latency target:** <200ms from play completion to stat on visual dashboard.

**Key constraint:** Must run on-device (Cactus + Gemma 4) for latency. Cloud routing via Cactus only for complex/historical queries.

---

## Tech Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| On-device inference | Cactus (YC S25) | Hybrid routing, mobile-first |
| Language model | Gemma 4 | First on-device voice-promptable model, <200ms |
| Complex queries | Gemini (via Cactus routing) | Historical/multi-step reasoning |
| Stats data | Sportradar API | Real-time + historical, free dev tier |
| STT | Whisper (on-device) | Low-latency transcription |
| TTS | System TTS or Coqui | Earpiece output |
| Platform | iOS/macOS (Cactus SDK) | Demo-friendly, on-device |

---

## Phase 1 — The Spotter

**Goal:** Two things:
1. **Pre-game:** Auto-build the broadcaster's spotting board overnight — formatted, sourced, ready at first pitch. Zero manual prep.
2. **Live game:** AI listens to the broadcast, understands the moment, and surfaces the right stat on a visual dashboard in <200ms. Broadcaster sees it and chooses whether to use it.

**Demo target:** Show pre-built spotting board → then show visual dashboard updating live during a game clip → then show opt-in voice query answered in <2 seconds.

---

### 1.0 Pre-Game Spotting Board (The Wedge)

**What it is:** The night before a game, BroadcastBrain auto-builds the broadcaster's spotting board — the same reference grid they currently spend hours building by hand.

**Why this first:** Zero live-game friction. The broadcaster doesn't change anything about how they call the game. They just show up with their board already done.

**What's on the auto-built board:**
- Full roster: name, number, position, headshot
- Key season stats per player (top 3 most contextually relevant)
- Recent form (last 5 games)
- Matchup notes (e.g., how this batter performs vs. this pitcher type)
- Storylines: milestones approaching, career highs, personal notes (sourced from Sportradar + news feed)

**Implementation:**
```python
# Run overnight, triggered N hours before first pitch
async def build_spotting_board(game_id: str, broadcaster_prefs: dict):
    # 1. Fetch full rosters + season stats from Sportradar
    home_roster = await sportradar.get_roster(game_id, 'home')
    away_roster = await sportradar.get_roster(game_id, 'away')
    
    # 2. For each player, generate top 3 contextual stats + storyline
    for player in home_roster + away_roster:
        stats = await sportradar.get_player_stats(player.id)
        player.spotlight = await gemma4.generate(
            prompt=SPOTTING_BOARD_PROMPT,
            context={ "player": player, "stats": stats, "game": game_id }
        )
    
    # 3. Render as visual dashboard (web) + exportable PDF
    return render_spotting_board(home_roster, away_roster)
```

**Spotting board prompt (Gemma 4):**
```
You are building a broadcaster's spotting board entry for {player_name}.

Stats: {stats_json}
Game context: {matchup}

Generate:
1. Top 3 stats most likely to be relevant during today's game (with Sportradar source)
2. One storyline or milestone worth mentioning (approaching record, personal story, recent streak)
3. One matchup note specific to today's opponent

Be concise. Each stat: one line. Storyline: one sentence. Source every stat.
```

**Output format:** Web dashboard + PDF export. Broadcaster can view on tablet in booth.

**Accuracy rule:** Every stat on the spotting board includes its Sportradar source endpoint. No hallucinated stats. If data is unavailable, field shows "—" not a guess.

---

### 1.1 Audio Capture Module

**Input:** Live broadcast audio stream (microphone input or system audio tap)

**Implementation:**
- Capture audio in 2-second rolling windows with 500ms overlap
- Use Apple's `AVAudioEngine` (iOS/macOS) for real-time audio tap
- Buffer size: 4096 samples at 16kHz (Whisper-compatible)
- Trigger transcription when audio energy exceeds silence threshold (`RMS > 0.01`)

**Output:** Raw PCM audio buffer → pass to STT

```swift
// Pseudocode
audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
    if buffer.rms > SILENCE_THRESHOLD {
        transcriptionQueue.async { transcribe(buffer) }
    }
}
```

---

### 1.2 STT — Speech-to-Text

**Model:** Whisper base.en (on-device, ~150MB, ~100ms on Apple Silicon)

**Implementation:**
- Use `whisper.cpp` or `WhisperKit` (Swift-native Whisper for Apple)
- Run on Neural Engine via Core ML conversion
- Transcribe 2-second windows → return text + confidence score
- Discard if confidence < 0.7 (noisy/crowd noise)

**Output:** Transcribed broadcaster speech string

**Example output:**
```
"touchdown by Mahomes, that's his third of the game"
```

---

### 1.3 Context Extraction — Gemma 4 (via Cactus)

**Model:** Gemma 4 on-device via Cactus SDK

**Goal:** Extract structured game context from the transcription

**Prompt:**
```
You are analyzing live sports broadcast commentary.

Transcript: "{transcription}"

Extract the following as JSON:
{
  "sport": "NFL|NBA|MLB|NHL|NCAAF|NCAAB|other",
  "event_type": "touchdown|interception|field_goal|basket|home_run|etc",
  "player_name": "string or null",
  "team": "string or null",
  "game_situation": "brief description",
  "stat_opportunity": "what stat would be most valuable to surface right now",
  "query_complexity": "simple|complex"
}

Only output valid JSON. No explanation.
```

**Output:** Structured JSON context object

**Routing logic:**
- `query_complexity: "simple"` → Gemma 4 handles stat retrieval + response generation on-device
- `query_complexity: "complex"` → Route to Gemini via Cactus hybrid routing

---

### 1.4 Stats Retrieval — Sportradar API

**API:** Sportradar NFL/NBA API (free developer tier)

**Base URL:** `https://api.sportradar.com/{sport}/trial/v7/en/`

**Key endpoints:**
```
# Live game summary
GET /games/{game_id}/summary.json

# Player season stats  
GET /players/{player_id}/profile.json

# Team season stats
GET /teams/{team_id}/statistics.json

# Play-by-play (for context)
GET /games/{game_id}/pbp.json
```

**Implementation:**
- Pre-cache current game's roster + team stats at game start (run before kickoff)
- On event detection: fire async request for player-specific stats
- Cache responses for 30s to avoid duplicate API calls on same player
- Fallback: if API call >100ms, use cached stats from pre-game fetch

**API key management:** Store in environment variable `SPORTRADAR_API_KEY`

**Rate limits (free tier):** 1 req/sec, 1000 req/month → pre-cache aggressively

**Pre-game cache structure:**
```json
{
  "home_team": {
    "id": "...",
    "players": [{"id": "...", "name": "...", "position": "...", "stats": {...}}]
  },
  "away_team": { ... },
  "game_id": "...",
  "season_stats": { ... }
}
```

---

### 1.5 Stat Generation — Gemma 4 On-Device

**Triggered when:** `query_complexity: "simple"` OR Gemini result returned

**Primary output:** Visual dashboard card — stat text + source citation
**Secondary output:** TTS to earpiece (only if broadcaster has opted in via button)

**Prompt (on-device, Gemma 4):**
```
You are a sports broadcast assistant. Generate a single stat card for the broadcaster's visual dashboard.

Game context: {context_json}
Relevant stats: {stats_json}

Rules:
- Maximum 15 words
- Lead with the most surprising or impressive number
- Sound like something a knowledgeable color commentator would say
- Do NOT include the player's name if it was just said (avoid repetition)
- Always include the source field (Sportradar endpoint or "live game")

Output JSON only:
{
  "stat_text": "...",
  "source": "Sportradar player profile",
  "confidence": "high|medium",
  "player": "name or null"
}
```

**Example outputs:**
- `{ "stat_text": "Third TD of the game — 12 TDs, zero picks in December", "source": "Sportradar season stats", "confidence": "high" }`
- `{ "stat_text": "847 yards this season, second most in the AFC", "source": "Sportradar player profile", "confidence": "high" }`

**Accuracy rule:** If `confidence: "medium"` (inferred, not directly from API), show a `~` prefix on the dashboard and do not read via TTS.

---

### 1.6 Complex Query Routing — Gemini via Cactus

**Triggered when:** `query_complexity: "complex"` (historical comparisons, multi-season trends, career records)

**Cactus routing config:**
```javascript
const cactus = new CactusClient({
  onDeviceModel: 'gemma-4',
  cloudModel: 'gemini-pro',
  routingStrategy: 'complexity-based'
});

const response = await cactus.generate({
  prompt: complexStatPrompt,
  context: gameContext,
  routing: 'cloud'  // force cloud for complex queries
});
```

**Prompt for Gemini:**
```
You are a sports broadcast assistant with access to historical stats.

Current moment: {game_context}
Live stats: {stats_json}

The broadcaster needs a historically significant stat for this moment.
- Reference historical comparisons, records, or career milestones
- Maximum 20 words
- Most impressive number first
- Output only the whisper text
```

---

### 1.7 Visual Dashboard

**Primary surface.** Always on during the game. Non-intrusive — broadcaster glances when ready.

**Layout:**
```
┌─────────────────────────────────────────────┐
│  BROADCASTBRAIN                    🎙 LIVE  │
├─────────────────────────────────────────────┤
│  CURRENT MOMENT                             │
│  Juan Soto — RISP, 2 outs, 7th inning      │
├─────────────────────────────────────────────┤
│  ⚡ LIVE STAT                               │
│  .347 avg with RISP this season             │
│  Ranks 3rd in MLB  · Sportradar ✓           │
├─────────────────────────────────────────────┤
│  SPOTTING BOARD  [tap to expand]            │
│  Soto  |  .287  |  18 HR  |  67 RBI        │
├─────────────────────────────────────────────┤
│  [🎤 VOICE QUERY]   [📋 FULL BOARD]        │
└─────────────────────────────────────────────┘
```

**Key behaviors:**
- Live stat card updates within <200ms of play completion
- Source citation shown on every stat (`Sportradar ✓`)
- Medium-confidence stats marked with `~` prefix and not read via TTS
- Spotting board accessible with one tap (no scrolling mid-game)
- Voice query button in bottom-left — one press to activate

**Broadcaster-requested dashboard features:**

- **Flashing light cue** *(Rich Ackerman)*: Small pulsing indicator in corner of screen when AI has a new stat ready. Non-intrusive — broadcaster finishes their sentence, glances at it. No audio, no pop-up.
  ```
  [●] — subtle pulse, orange dot, top-right corner
  Clears when broadcaster views the stat card
  ```

- **Running score tracker** *(Bob Heussler — "godsend")*: Real-time scoring run display. Tracks team runs over a rolling time window. Bob currently writes this by hand, risking missing live action.
  ```
  NETS RUN: 11-0  over 1:34  ← auto-computed from play-by-play
  ```
  Implementation: maintain rolling score log from Sportradar PBP feed; compute run on every scoring event.

- **Milestone / streak alerts** *(Trey Redfield)*: If a player is mid-streak (e.g., 10-game hitting streak) and approaching an at-bat that could end it, dashboard surfaces a proactive alert — not a voice whisper, just a visual flag.
  ```
  ⚠️  Soto — 10-game hit streak ON THE LINE  (0-for-3 tonight)
  ```
  Implementation: pre-compute active streaks during spotting board build; monitor each at-bat against streak state.

- **Story reminder queue** *(Ackerman's split-screen concept)*: Second panel alongside live stats showing broadcaster's own pre-planned story bullets — items they intended to hit during the game. AI tracks which have been mentioned (via STT) and surfaces unmentioned ones during lulls.
  ```
  ┌─ LIVE STAT ──────┬─ YOUR STORIES ──────────────────┐
  │ Soto .347 RISP   │ ○ Soto contract extension talks  │
  │ Sportradar ✓     │ ✓ Judge leadoff HR streak        │
  │                  │ ○ Bullpen usage last 7 days       │
  └──────────────────┴─────────────────────────────────┘
  ```

**Stack:** React web app (runs in browser on tablet in booth) + WebSocket feed from local inference server

---

### 1.8 TTS + Opt-In Voice Output

**This is secondary.** TTS only fires when broadcaster explicitly triggers it.

**Trigger:** Physical button press (or on-screen button) — broadcaster chooses the moment.

**Why not proactive:** Play-by-play announcers are talking continuously. Unsolicited audio in the earpiece causes sensory overload (direct broadcaster feedback). Color commentators are the primary TTS users — they have natural dead air to fill.

**Engine:** AVSpeechSynthesizer (iOS, zero latency, no network) or Coqui TTS (more natural)

**Voice config:**
```swift
let utterance = AVSpeechUtterance(string: statText)
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
utterance.rate = 0.52  // slightly faster than normal speech
utterance.pitchMultiplier = 0.95  // slightly lower, authoritative
utterance.volume = 0.9

synthesizer.speak(utterance)
```

**Output device:** Route to Bluetooth earpiece via `AVAudioSession` with `.allowBluetooth` option

**Interruption handling:** Cancel in-progress utterance if broadcaster triggers a new query

---

### 1.9 Voice Query Mode

**Trigger:** Button press only (no wake word — reduces accidental triggers mid-call)

**Primary users:** Color commentators (have natural dead air). Play-by-play announcers use during pitch clock, timeouts, replay reviews.

**Flow:**
1. Broadcaster presses button
2. Record up to 8-second voice query
3. Transcribe with Whisper
4. Send to Gemma 4 (simple) or Gemini (complex) with full game context + spotting board as grounding
5. Answer shown on visual dashboard + read to earpiece simultaneously

**Example queries:**
- "How does Soto hit with runners in scoring position?"
- "What's Judge's home run total vs lefties this year?"
- "Is this a career high for him?"

**Accuracy rule:** Same as dashboard — every answer cites its Sportradar source. If the answer can't be sourced from the API, Gemma 4 says "I don't have verified data on that" rather than guessing.

---

### 1.10 End-to-End Latency Budget

| Stage | Target | Notes |
|-------|--------|-------|
| Audio buffer fill | ~500ms | 2s window, 500ms overlap |
| STT (Whisper on-device) | ~100ms | Neural Engine |
| Context extraction (Gemma 4) | ~80ms | On-device |
| Sportradar API call | ~80ms | Cached data preferred |
| Stat generation (Gemma 4) | ~80ms | On-device |
| TTS first word | ~50ms | AVSpeechSynthesizer |
| **Total** | **~390ms** | Within 4-sec broadcast window ✓ |

*Complex/Gemini path adds ~400ms (still <1 sec)*

---

### 1.11 Demo Script (5 Minutes)

1. **Spotting board (60s):** Open the pre-built spotting board for tonight's Mets game. "This took zero minutes to build. Juan Soto, Pete Alonso, full roster — stats, storylines, matchup notes. Auto-generated overnight." Judges see something they immediately recognize.

2. **Live game clip (60s):** Play a real MLB clip. Soto hits with runners on base. Visual dashboard card updates: "Soto — .347 avg with RISP, 3rd in MLB · Sportradar ✓". "The broadcaster saw that in under 200ms. They decide if they use it."

3. **Voice query (45s):** Press the button. Ask: "How does Soto hit against lefties this season?" Answer appears on dashboard + plays in earpiece in ~2 seconds. "Color commentator presses a button, asks anything, gets a sourced answer instantly."

4. **Routing transparency (30s):** Show the routing log — "That was Gemma 4 on-device. Complex historical queries route to Gemini via Cactus." Kill internet. Show it still works. "On-device is not a feature — it's the latency requirement."

5. **The pitch (45s):** "4 broadcasters told us they use 25% of their prep. We built the AI that makes the other 75% useful — before the game and during it. The broadcaster stays in control. The AI has the right stat ready when they reach for it."

---

## Phase 2 — The Producer

**Goal:** Extend the AI beyond the earpiece — trigger graphics overlays, flag social-worthy clips, and cue the replay director. One model running every production role simultaneously.

**Built after Phase 1 is stable.**

---

### 2.1 Graphics Overlay Trigger

**What it does:** When a stat is whispered, simultaneously push the same stat as a lower-third graphic overlay to the broadcast output.

**Implementation:**
- REST endpoint on local server: `POST /overlay` with `{ text, duration_ms, style }`
- Overlay client: OBS WebSocket plugin OR Caspar CG (broadcast-standard)
- For demo: OBS Studio with WebSocket plugin (free, runs on laptop)

**OBS WebSocket integration:**
```javascript
const OBSWebSocket = require('obs-websocket-js');
const obs = new OBSWebSocket();

await obs.connect('ws://localhost:4455', 'password');

async function triggerOverlay(statText) {
  // Update the text source
  await obs.call('SetInputSettings', {
    inputName: 'LowerThird',
    inputSettings: { text: statText }
  });
  
  // Show the scene item
  await obs.call('SetSceneItemEnabled', {
    sceneName: 'Main',
    sceneItemId: LOWER_THIRD_ID,
    sceneItemEnabled: true
  });
  
  // Auto-hide after 5 seconds
  setTimeout(async () => {
    await obs.call('SetSceneItemEnabled', {
      sceneName: 'Main',
      sceneItemId: LOWER_THIRD_ID,
      sceneItemEnabled: false
    });
  }, 5000);
}
```

**Graphic styles by event type:**
```json
{
  "touchdown": { "color": "#F97316", "duration": 6000, "position": "lower_third" },
  "record_broken": { "color": "#22C55E", "duration": 8000, "position": "full_screen_lower" },
  "stat_compare": { "color": "#FFFFFF", "duration": 5000, "position": "lower_third" }
}
```

---

### 2.2 Viral Clip Flagging

**What it does:** Detect highlight-worthy moments in real time and flag them for social/digital team.

**Trigger signals** (combine any 2+):
- Crowd noise spike (RMS energy jump >40% in 500ms)
- Game event type: touchdown, interception, dunk, home run
- Broadcaster voice pitch increase >15% above baseline
- Stat-worthy moment (new season high, record broken)

**Implementation:**

```python
class ViralDetector:
    def __init__(self):
        self.crowd_baseline = deque(maxlen=30)  # 30s rolling baseline
        self.broadcaster_baseline = deque(maxlen=60)
        
    def score_moment(self, audio_frame, game_event, stat_context):
        score = 0
        
        # Crowd noise spike
        crowd_rms = compute_rms(audio_frame)
        if crowd_rms > np.mean(self.crowd_baseline) * 1.4:
            score += 30
            
        # High-value game event
        high_value_events = ['touchdown', 'interception', 'pick_six', 'dunk', 'home_run']
        if game_event.type in high_value_events:
            score += 40
            
        # Record or season high
        if stat_context.get('is_record') or stat_context.get('is_season_high'):
            score += 30
            
        return score  # 0-100
    
    def should_flag(self, score):
        return score >= 60
```

**Output:** When flagged, write to `clips.log` with:
```json
{
  "timestamp": "14:32:17",
  "game_clock": "Q3 8:42",
  "score": 85,
  "reason": ["crowd_spike", "touchdown", "season_high"],
  "suggested_caption": "Mahomes TD #3 — 12 TDs, 0 INTs in December",
  "clip_window": { "start_offset": -8, "end_offset": 5 }
}
```

**Demo:** Show the `clips.log` updating in real time during the game clip.

---

### 2.3 Replay Director Cuing

**What it does:** After a flagged moment, automatically suggest the best replay angle to the director.

**Replay angle logic:**

```python
REPLAY_RULES = {
    "touchdown_pass": ["QB release angle", "receiver catch + defender", "end zone celebration"],
    "touchdown_run": ["line break point", "open field run", "goal line push"],
    "interception": ["QB eyes + throw", "DB break on ball", "return"],
    "field_goal": ["kicker + snap", "uprights wide angle"],
    "fumble": ["ball carrier contact", "loose ball scramble"],
}

def suggest_replay(event_type, available_cameras):
    angles = REPLAY_RULES.get(event_type, ["wide angle", "player close-up"])
    return {
        "primary": angles[0],
        "secondary": angles[1] if len(angles) > 1 else None,
        "suggested_order": angles
    }
```

**Output:** Push replay suggestion to director UI (simple web dashboard) via WebSocket:
```json
{
  "event": "touchdown_pass",
  "replay_suggestion": {
    "primary": "QB release angle",
    "secondary": "receiver catch + defender",
    "timing": "show within 8 seconds of event"
  }
}
```

---

### 2.4 Director Dashboard (UI)

**Simple web dashboard showing all Phase 2 outputs in real time.**

**Stack:** React + WebSocket server (Node.js)

**Layout:**
```
┌─────────────────────────────────────────────────┐
│  BROADCASTBRAIN PRODUCER DASHBOARD              │
├──────────────┬──────────────┬───────────────────┤
│ LIVE WHISPER │ CLIP FLAGS   │ REPLAY QUEUE      │
│              │              │                   │
│ "Third TD,   │ 🔴 Q3 8:42  │ → QB release      │
│  12 TDs 0    │  Score: 85  │ → Receiver catch  │
│  picks Dec"  │  Reason:    │                   │
│              │  crowd+TD   │                   │
│              │  +record    │                   │
├──────────────┴──────────────┴───────────────────┤
│ GRAPHICS: [ACTIVE] "12 TDs, 0 INTs in December" │
│ OBS: Connected ✓  Sportradar: Connected ✓        │
└─────────────────────────────────────────────────┘
```

**WebSocket events:**
```javascript
// Server emits:
socket.emit('whisper', { text, timestamp, complexity, latency_ms });
socket.emit('clip_flag', { timestamp, score, reason, suggested_caption });
socket.emit('replay_cue', { event_type, primary_angle, secondary_angle });
socket.emit('overlay_active', { text, duration_ms });
```

---

## Phase 2 Feature Additions (broadcaster-requested)

### Esoteric / Disruptor Metrics *(Bob Heussler)*

Bob specifically asked for stats that don't appear in standard game recaps — deflections, "disruptor" metrics, hustle stats. These are often what make a color commentator sound like they really know the game.

**Implementation:**
- Check Sportradar advanced stats endpoints per sport (NBA: `deflections`, `contested_shots`, `loose_balls_recovered`; MLB: sprint speed, exit velocity, launch angle)
- Tag these as "esoteric" in the stat card — subtle visual indicator so broadcaster knows it's unusual
- Pre-fetch these during spotting board build; surface during relevant moments

```
⚡ ESOTERIC  Soto exit velocity tonight: 108.2 mph  (top 3% MLB)
            Sportradar Statcast ✓
```

---

### Secondary Contextual Stats *(Rich Ackerman)*

Rich wants stats anchored to specific game events: "how has this team performed since that missed field goal?" or "how long has this scoring drought been?"

**Implementation:**
- Maintain a game event log with timestamps from PBP feed
- On each scoring event, compute: time since last score, team record since key play X
- Surface as "since then" card when relevant:

```
SCORING DROUGHT: Nets scoreless for 4:22 — longest drought of the game
SINCE THAT MISS: Chiefs 0-for-3 in red zone attempts
```

---

## Phase 3 — Roadmap

### Matchup-to-Matchup Memory *(Trey Redfield)*

Save insights from one game and auto-surface them weeks later when the same two teams meet again.

**What gets saved:**
- Stat cards that the broadcaster used (inferred from STT — if they said the stat on air, it resonated)
- Storylines that were mid-game (player on streak, injury return, contract drama)
- Unmentioned story bullets (the 75% that didn't get used — maybe relevant next time)

**Implementation:** Game archive per matchup pair. When building next spotting board for same matchup, pull prior game's archive and diff against current stats.

---

### Expand User Base

- **Local news / on-field reporters** *(Rich Ackerman)*: Same core tech — listens to context, surfaces facts — applied to live field reporting. Reporter covering a press conference gets relevant background on whoever is speaking. Different data sources (news APIs vs. Sportradar) but same architecture.
- **Freelance / college market** *(280+ programs with no research staff)*: Full suite replaces the research team they can't afford. Already in deck as a target segment.

---

## File Structure

```
broadcastbrain/
├── ios/                        # Phase 1: iOS/macOS app
│   ├── AudioCapture.swift      # AVAudioEngine tap
│   ├── WhisperTranscriber.swift # STT via WhisperKit
│   ├── CactusClient.swift      # Cactus SDK wrapper
│   ├── SportradarAPI.swift     # Stats fetching + caching
│   ├── StatGenerator.swift     # Gemma 4 prompt + output
│   ├── EarpieceOutput.swift    # TTS + audio routing
│   └── VoiceQueryMode.swift    # Hey Brain wake word + query
│
├── producer/                   # Phase 2: Producer layer
│   ├── server.js               # WebSocket server (Node.js)
│   ├── obs_trigger.js          # OBS WebSocket integration
│   ├── viral_detector.py       # Clip flagging logic
│   ├── replay_rules.py         # Replay angle suggestions
│   └── dashboard/              # React web dashboard
│       ├── App.jsx
│       └── components/
│           ├── WhisperFeed.jsx
│           ├── ClipFlags.jsx
│           └── ReplayQueue.jsx
│
├── data/
│   ├── game_cache.json         # Pre-cached game stats
│   └── clips.log               # Viral clip log
│
├── config/
│   └── .env                    # SPORTRADAR_API_KEY, OBS_WS_PASSWORD
│
└── SPEC.md                     # This file
```

---

## Environment Setup

```bash
# Clone and install
git clone <repo>
cd broadcastbrain

# iOS/macOS dependencies
# Add to Xcode project:
# - WhisperKit (Swift Package Manager)
# - Cactus SDK (follow Cactus docs)

# Phase 2 dependencies
cd producer
npm install obs-websocket-js ws express react

pip install numpy scipy pyaudio

# Environment variables
cp config/.env.example config/.env
# Fill in: SPORTRADAR_API_KEY, OBS_WS_PASSWORD

# Sportradar API (free dev key)
# Sign up at developer.sportradar.com
# Use NFL trial API v7
```

---

## Key APIs & Docs

- **Cactus SDK:** https://github.com/cactus-compute/cactus (follow their Swift/JS quickstart)
- **Sportradar API:** developer.sportradar.com → NFL Trial API v7
- **WhisperKit:** github.com/argmaxinc/WhisperKit
- **OBS WebSocket:** github.com/obsproject/obs-websocket (v5 protocol)
- **Gemma 4 via Cactus:** Use Cactus `onDeviceModel: 'gemma-4'` config

---

## Hackathon Prioritization

**Must have (hours 0–14):**
- [ ] Pre-game spotting board: Sportradar fetch → Gemma 4 → rendered board for one game
- [ ] Audio capture + Whisper STT working
- [ ] Gemma 4 context extraction via Cactus
- [ ] Live stat generation with source citation (Sportradar)
- [ ] Visual dashboard showing live stat cards
- [ ] End-to-end demo on one sport (MLB — Mets game)

**Should have (hours 14–20):**
- [ ] Opt-in voice query (button-triggered, not wake word)
- [ ] OBS overlay trigger (Phase 2 graphics)
- [ ] Viral clip flagging

**Nice to have (final 2 hrs):**
- [ ] Director dashboard showing all outputs
- [ ] Replay cuing
- [ ] Multi-sport support (NBA)

---

## The One Metric That Wins

**Under 200ms from play completion to stat on the visual dashboard.**

Record it. Show the latency counter on screen during the demo. That number is the moat.

**The secondary proof point:** Show the spotting board first. It's the most immediately legible demo — judges understand it instantly, it validates the broadcaster research, and it has zero latency risk.
