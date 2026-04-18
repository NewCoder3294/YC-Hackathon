# Data Contracts — Frontend ↔ Backend

Canonical shapes the frontend expects. Backend devs: use these for `match_cache.json`, the Gemma 4 function toolbox, the Zustand event bus, and the `askGemma` response.

Derived from `SPEC.md`. If frontend designs diverge from these, this file is updated FIRST, then code follows.

---

## 1. `match_cache.json` (bundled at build, loaded on app start)

```ts
type MatchCache = {
  match: Match
  teams: { home: Team; away: Team }            // home = Argentina, away = France
  players: Player[]                             // 46 total (23 + 23)
  storylines: Storyline[]                       // referenced by player.storyline_ids
  precedent_index: PrecedentPattern[]           // used by Feature 2 3-card stack
}

type Match = {
  id: string                                    // 'arg-vs-fra-2022-wc-final'
  competition: 'FIFA World Cup 2022 Final'
  venue: string                                 // 'Lusail Stadium'
  capacity: number
  kickoff_iso: string                           // '2022-12-18T15:00:00Z'
  referee: { name: string; federation: string; tournament_yellows: number }
  weather: { temp_c: number; condition: string }
}

type Team = {
  id: string                                    // 'arg' | 'fra'
  name: string                                  // 'Argentina'
  flag_svg_path: string
  color_hex: string                             // pane header tint
  tournament_record: { w: number; d: number; l: number; gf: number; ga: number }
  h2h: {
    all_time: { w: number; d: number; l: number }
    last_wc_meeting?: string                    // '2018 R16: FRA 4-3 (Mbappé ×2)'
  }
}

type Player = {
  id: string
  team_id: string
  shirt_number: number
  name: string
  position: 'GK' | 'DF' | 'MF' | 'FW'
  age: number
  club: string
  headshot_url?: string

  // Three stat cohorts. Keys are position-dependent; UI picks 3–10 based on
  // commentator's MODE and density slider (see §4).
  stats: {
    tournament: Record<string, number | string>    // goals, assists, xG, KP, xA, MIN
    career: Record<string, number | string>
    form_last_5: Record<string, number | string>
  }

  role_tags: string[]                               // ['TOP SCORER', 'CAPTAIN', 'MOST KP']
  storyline_ids: string[]                           // → Storyline[]
  h2h_notes: string[]                               // VS-opponent specific lines
  didnt_know: string[]                              // esoteric / trivia

  status: 'fit' | 'doubtful' | 'injured' | 'suspended' | 'not_in_squad'
}

type Storyline = {
  id: string
  player_ids: string[]                              // can attach to multiple players
  text: string                                      // "LAST DANCE — 5th & final WC at 35"
  category: 'last_dance' | 'redemption' | 'milestone' | 'family' | 'rivalry' | 'tactical' | 'record_watch'
  priority_by_mode: {
    stats_first: number
    story_first: number
    tactical: number
  }
}

type PrecedentPattern = {
  id: string
  trigger: {
    event_type: 'goal' | 'penalty' | 'red_card' | 'substitution' | 'shot_on_target' | 'half_time' | 'extra_time' | 'penalty_shootout'
    minute_range?: [number, number]
    score_state?: string                            // '2-0', 'trailing_2_goals'
    player_filters?: { age_lt?: number; new_comer?: boolean }
  }
  stat_text: string                                 // "Teams leading 2-0 in WC Finals have won 19/22 since 1970"
  counter_narrative?: string                        // "BUT 2/22 came back — both in ET (1966, 1994)"
  category: 'statistical' | 'historical' | 'tactical' | 'emotional'
  sources: string[]                                 // ['FIFA', 'Sportradar', 'StatsBomb']
}
```

---

## 2. Gemma 4 function toolbox

These are the functions Gemma 4 can call on-device. All resolve against the in-memory `match_cache.json` — zero network calls during the live demo.

```ts
get_player_stat(player_name: string, situation?: string)
  → {
      stat_text: string            // human-readable line
      value: number | string
      source: 'Sportradar' | 'StatsBomb' | 'FIFA'
      confidence_high: boolean     // false if derived/computed, true if direct lookup
    }
  // situation examples: 'vs_lhp' → N/A for soccer, 'vs_france_all_time',
  // 'in_knockouts', 'current_tournament', 'career'

get_team_stat(team: 'home' | 'away' | 'arg' | 'fra', metric: string)
  → { stat_text, value, source, confidence_high }
  // metric examples: 'possession_pct', 'xg_total', 'set_piece_conversion',
  // 'ppda', 'final_third_entries', 'corners_for'

get_match_context(match_id: string)
  → {
      score: { home: number; away: number }
      minute: number
      added_time: number | null
      phase: 'pre_match' | '1st_half' | 'half_time' | '2nd_half' | 'ET_1st' | 'ET_2nd' | 'penalties' | 'full_time'
      possession_pct: { home: number; away: number }
      shots: { home: number; away: number }
      shots_on_target: { home: number; away: number }
      recent_events: MatchEvent[]
    }

get_historical(query: string)
  → PrecedentPattern[] | null
  // "2-0 lead in WC knockouts", "French comebacks in WC", "hat-tricks in WC finals"
  // Returns empty array if no precedent matches. Gemma 4 must then NOT fabricate.

get_commentator_profile()
  → CommentatorProfile    // see §4
```

---

## 3. Zustand event bus

All cross-pane communication flows through one typed event bus. Pipeline emits, panes subscribe.

```ts
type EventBusMessage =
  // Whisper-surfaced (Feature 2)
  | { type: 'stat_card';       player_id: string; stat_text: string; source: string; latency_ms: number; confidence_high: boolean }
  | { type: 'precedent';       pattern_id: string; stat_text: string; category: string }
  | { type: 'counter_narrative'; text: string; for_team: 'home' | 'away'; tone: 'calming' | 'dramatic' }
  | { type: 'running_score';   score: { home: number; away: number }; minute: number; momentum?: string }
  | { type: 'momentum_tag';    text: string; team: 'home' | 'away' }      // "FRA RUN: 2 goals in 1:38"
  | { type: 'streak_alert';    player_id: string; streak_text: string; at_risk: boolean }

  // STT-driven (Feature 2 dup suppression + story queue)
  | { type: 'transcript';      text: string; confidence: number }
  | { type: 'story_tick';      story_id: string }                          // STT detected commentator mentioned it

  // Voice-commanded (Feature 3)
  | { type: 'voice_command';   raw: string; classified_as: 'widget' | 'query' | 'unclear' }
  | { type: 'widget_built';    widget: WidgetSpec }                        // pin-to-pane widget
  | { type: 'answer_card';     question: string; answer: string; source: string; confidence_high: boolean; latency_ms: number }
  | { type: 'no_data';         question: string }                          // trust escape

  // UI → pipeline
  | { type: 'opt_in_tts';      enabled: boolean }
  | { type: 'mode_changed';    mode: 'stats_first' | 'story_first' | 'tactical' | 'custom' }
  | { type: 'density_changed'; density: 'compact' | 'standard' | 'full'; scope: 'global' | PlayerId }

type WidgetSpec = {
  id: string
  kind: 'timeline' | 'bar_chart' | 'comparison_table' | 'heat_map' | 'shot_map'
  title: string
  data: any                                   // widget-specific
  pinned: boolean
  source: string
}
```

---

## 4. CommentatorProfile (persisted locally)

```ts
type CommentatorProfile = {
  id: string
  mode: 'stats_first' | 'story_first' | 'tactical' | 'custom'
  density: 'compact' | 'standard' | 'full'

  // Commentator's preferred stats by position (learned over time).
  // Position → ordered list of stat keys. UI shows top N per density.
  pinned_stats_by_position: Record<'GK' | 'DF' | 'MF' | 'FW', string[]>

  pinned_storyline_ids: string[]                // always-surface these
  hidden_storyline_ids: string[]                // never-surface these

  annotations: Record<string, string>           // player_id → custom note

  // Implicit learning signal: every time commentator swaps a stat via
  // long-press, log it here. Gemma 4 uses this to reorder pinned_stats
  // automatically before future matches.
  stat_swap_history: Array<{
    when_iso: string
    player_id: string
    from_stat_key: string
    to_stat_key: string
  }>

  // Gemma 4 uses recent transcripts (last 3 matches) + STT of on-air
  // stat mentions to re-rank pinned_stats over time.
  transcript_corpus: Array<{ match_id: string; transcript: string }>
}
```

---

## 5. `askGemma` — the single integration contract

All three features call this. See `SPEC.md §Shared Architecture` for full pipeline.

```ts
askGemma(
  input: { prompt?: string; audio?: ArrayBuffer },
  context: {
    mode: 'stats_first' | 'story_first' | 'tactical' | 'custom'
    match_state: ReturnType<typeof get_match_context>
    recent_transcripts: string[]                 // last ~60s of broadcaster speech
    commentator_profile: CommentatorProfile
  },
  routing: 'auto' | 'local' | 'cloud'            // 'local' = airplane-mode-safe
)
  → Promise<{
      stat_text: string
      source: string
      confidence_high: boolean                   // if false, caller must NOT render via TTS
      player_id?: string
      latency_ms: number
      transcript?: string                        // populated when input.audio was provided
      widget_spec?: WidgetSpec                   // populated when a voice command built a widget
      precedent?: PrecedentPattern               // populated when Gemma 4 surfaced a precedent
      counter_narrative?: { text: string; for_team: 'home' | 'away' }
    }>
```

**Rules:**
- `confidence_high: false` → caller displays the card but **does not** TTS it. No `~` prefix in v2 (removed).
- `source` is always present. If no source can be cited, the function must return `{ type: 'no_data', ... }` via the event bus instead.
- `routing: 'local'` is the demo path. `'cloud'` is reserved for post-demo complex historicals.

---

## 6. Sources of truth for seed data

- **Player/team/match data:** Sportradar Soccer API (archive mode for 2022 WC) OR StatsBomb Open Data (free, event-level, this specific match included).
- **Storylines:** hand-curated + Gemma 4-generated from source articles. Every storyline must reference a source URL.
- **Precedent patterns:** hand-curated CSV seeded from FIFA historical records. ~30 patterns is enough for the demo.
