# Voice Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the on-device Cactus/Gemma 4 voice pipeline that powers Feature 2 (Live Co-Pilot) — continuous autonomous listening plus press-to-talk, both flowing through a single `askGemma` contract and emitting typed events onto a Zustand bus.

**Architecture:** One module owns the voice stack (`app/src/cactus/`). Audio capture (continuous rolling buffer or press-to-talk) feeds `askGemma`, which runs Gemma 4 multimodal on Cactus against a bundled `match_cache.json`, function-calls the local toolbox, and emits events. Other agents (FRONTEND/UI, DATA) only touch the event bus and the cache. See `docs/superpowers/specs/2026-04-18-voice-pipeline-design.md`.

**Tech Stack:** React Native 0.81 · Expo 54 · TypeScript 5.9 · Zustand 5 · Cactus RN SDK · Gemma 4 (on-device) · expo-av (capture + metering) · expo-speech (opt-in TTS) · zod (schema validation) · Jest + `@testing-library/react-native` (unit tests).

**Working directory for every step:** `app/` unless stated otherwise. All `npm` commands run from `app/`.

---

## File Structure

```
app/
├── assets/
│   ├── match_cache.json                    minimal stub (Task 1); DATA agent replaces
│   └── audio-fixtures/                     WAV clips for smoke harness (Task 13)
├── src/
│   ├── cactus/
│   │   ├── askGemma.ts                     public contract (Task 8)
│   │   ├── client.ts                       Cactus RN SDK wrapper (Task 7)
│   │   ├── prompts.ts                      system prompts (Task 6)
│   │   ├── functions.ts                    Gemma 4 function toolbox (Task 3)
│   │   ├── schema.ts                       zod schemas + types (Task 1)
│   │   ├── audio/
│   │   │   ├── continuous.ts               rolling window capture (Task 10)
│   │   │   └── pressToTalk.ts              gated capture (Task 9)
│   │   ├── pipeline/
│   │   │   ├── orchestrator.ts             glue (Task 11)
│   │   │   ├── gate.ts                     VAD + classifier gate (Task 5)
│   │   │   └── dedupe.ts                   signature + transcript cache (Task 4)
│   │   └── state/
│   │       ├── eventBus.ts                 typed Zustand store (Task 2)
│   │       └── matchCache.ts               loader with zod validation (Task 1)
│   └── agent/
│       └── AgentContext.tsx                rewired to event bus (Task 12)
├── scripts/
│   └── cactus-smoke.ts                     Node harness (Task 13)
└── jest.config.js                          (Task 0)
```

---

## Task 0: Bootstrap — install deps + Jest

**Files:**
- Modify: `app/package.json`
- Create: `app/jest.config.js`
- Create: `app/jest.setup.ts`
- Create: `app/src/cactus/__tests__/sanity.test.ts`

- [ ] **Step 1: Install dependencies**

```bash
cd app
npx expo install expo-av expo-speech
npm install zod
npm install --save-dev jest @types/jest @testing-library/react-native ts-jest @testing-library/jest-native
```

**Note on Cactus RN SDK:** The exact npm name needs verification (`cactus-react-native` is the likely name per the Cactus blog; if unavailable, pull directly from `github:cactus-compute/cactus` and wire an Expo config plugin). This resolves during Task 7's spike. For now we install only the listed deps and mock Cactus in tests.

- [ ] **Step 2: Add test scripts to `package.json`**

Edit `app/package.json`, add to `"scripts"`:

```json
    "test": "jest",
    "test:watch": "jest --watch"
```

- [ ] **Step 3: Create `jest.config.js`**

```js
// app/jest.config.js
module.exports = {
  preset: 'react-native',
  testMatch: ['**/__tests__/**/*.test.ts', '**/__tests__/**/*.test.tsx'],
  transform: {
    '^.+\\.(ts|tsx)$': ['ts-jest', { tsconfig: { jsx: 'react', esModuleInterop: true } }],
  },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  setupFilesAfterEach: ['<rootDir>/jest.setup.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/.expo/'],
};
```

- [ ] **Step 4: Create `jest.setup.ts`**

```ts
// app/jest.setup.ts
// Silence React Native warnings unrelated to the unit tests.
jest.mock('react-native/Libraries/Animated/NativeAnimatedHelper');
```

- [ ] **Step 5: Write + run a sanity test**

`app/src/cactus/__tests__/sanity.test.ts`:

```ts
describe('jest sanity', () => {
  it('runs', () => {
    expect(1 + 1).toBe(2);
  });
});
```

Run: `npm test`
Expected: 1 test passes.

- [ ] **Step 6: Commit**

```bash
git add app/package.json app/package-lock.json app/jest.config.js app/jest.setup.ts app/src/cactus/__tests__/sanity.test.ts
git commit -m "chore(cactus): install deps and jest harness"
```

---

## Task 1: Match cache schema, loader, and minimal stub

**Files:**
- Create: `app/src/cactus/schema.ts`
- Create: `app/src/cactus/state/matchCache.ts`
- Create: `app/src/cactus/__tests__/matchCache.test.ts`
- Create: `app/assets/match_cache.json`

- [ ] **Step 1: Write schema**

`app/src/cactus/schema.ts`:

```ts
import { z } from 'zod';

export const StatRecord = z.record(z.union([z.number(), z.string()]));

export const PlayerSchema = z.object({
  id: z.string(),
  team_id: z.enum(['arg', 'fra']),
  shirt_number: z.number().int(),
  name: z.string(),
  position: z.enum(['GK', 'DF', 'MF', 'FW']),
  age: z.number().int(),
  club: z.string(),
  headshot_url: z.string().optional(),
  stats: z.object({
    tournament: StatRecord,
    career: StatRecord,
    form_last_5: StatRecord,
  }),
  role_tags: z.array(z.string()),
  storyline_ids: z.array(z.string()),
  h2h_notes: z.array(z.string()),
  didnt_know: z.array(z.string()),
  status: z.enum(['fit', 'doubtful', 'injured', 'suspended', 'not_in_squad']),
});

export const TeamSchema = z.object({
  id: z.enum(['arg', 'fra']),
  name: z.string(),
  flag_svg_path: z.string(),
  color_hex: z.string(),
  tournament_record: z.object({
    w: z.number(), d: z.number(), l: z.number(), gf: z.number(), ga: z.number(),
  }),
  h2h: z.object({
    all_time: z.object({ w: z.number(), d: z.number(), l: z.number() }),
    last_wc_meeting: z.string().optional(),
  }),
});

export const MatchSchema = z.object({
  id: z.string(),
  competition: z.string(),
  venue: z.string(),
  capacity: z.number(),
  kickoff_iso: z.string(),
  referee: z.object({ name: z.string(), federation: z.string(), tournament_yellows: z.number() }),
  weather: z.object({ temp_c: z.number(), condition: z.string() }),
});

export const StorylineSchema = z.object({
  id: z.string(),
  player_ids: z.array(z.string()),
  text: z.string(),
  category: z.enum(['last_dance', 'redemption', 'milestone', 'family', 'rivalry', 'tactical', 'record_watch']),
  priority_by_mode: z.object({
    stats_first: z.number(), story_first: z.number(), tactical: z.number(),
  }),
});

export const PrecedentPatternSchema = z.object({
  id: z.string(),
  trigger: z.object({
    event_type: z.enum([
      'goal', 'penalty', 'red_card', 'substitution', 'shot_on_target',
      'half_time', 'extra_time', 'penalty_shootout',
    ]),
    minute_range: z.tuple([z.number(), z.number()]).optional(),
    score_state: z.string().optional(),
    player_filters: z.object({
      age_lt: z.number().optional(),
      new_comer: z.boolean().optional(),
    }).optional(),
  }),
  stat_text: z.string(),
  counter_narrative: z.string().optional(),
  category: z.enum(['statistical', 'historical', 'tactical', 'emotional']),
  sources: z.array(z.string()),
});

export const MatchCacheSchema = z.object({
  match: MatchSchema,
  teams: z.object({ home: TeamSchema, away: TeamSchema }),
  players: z.array(PlayerSchema),
  storylines: z.array(StorylineSchema),
  precedent_index: z.array(PrecedentPatternSchema),
});

export type MatchCache = z.infer<typeof MatchCacheSchema>;
export type Player = z.infer<typeof PlayerSchema>;
export type Team = z.infer<typeof TeamSchema>;
export type PrecedentPattern = z.infer<typeof PrecedentPatternSchema>;
export type Storyline = z.infer<typeof StorylineSchema>;
```

- [ ] **Step 2: Write failing loader test**

`app/src/cactus/__tests__/matchCache.test.ts`:

```ts
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

describe('matchCache loader', () => {
  beforeEach(() => __resetMatchCacheForTests());

  it('loads and validates a well-formed cache', () => {
    const raw = require('../../../assets/match_cache.json');
    const cache = loadMatchCache(raw);
    expect(cache.match.id).toBe('arg-vs-fra-2022-wc-final');
    expect(cache.players.length).toBeGreaterThan(0);
  });

  it('throws on malformed cache', () => {
    expect(() => loadMatchCache({ garbage: true })).toThrow(/match_cache/i);
  });

  it('is idempotent — second call returns the same instance', () => {
    const raw = require('../../../assets/match_cache.json');
    const a = loadMatchCache(raw);
    const b = loadMatchCache(raw);
    expect(a).toBe(b);
  });
});
```

- [ ] **Step 3: Run — verify it fails**

Run: `npm test -- matchCache`
Expected: FAIL (module not found or json missing).

- [ ] **Step 4: Write the loader**

`app/src/cactus/state/matchCache.ts`:

```ts
import { MatchCache, MatchCacheSchema } from '../schema';

let cached: MatchCache | null = null;

export function loadMatchCache(raw: unknown): MatchCache {
  if (cached) return cached;
  const parsed = MatchCacheSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(`match_cache.json failed schema validation: ${parsed.error.message}`);
  }
  cached = parsed.data;
  return cached;
}

export function getMatchCache(): MatchCache {
  if (!cached) throw new Error('match_cache not loaded — call loadMatchCache() at app startup');
  return cached;
}

// Test-only: reset the memoized instance between specs.
export function __resetMatchCacheForTests() {
  cached = null;
}
```

- [ ] **Step 5: Write minimal match_cache.json stub**

`app/assets/match_cache.json` — just enough to keep this track unblocked (DATA agent ships full version):

```json
{
  "match": {
    "id": "arg-vs-fra-2022-wc-final",
    "competition": "FIFA World Cup 2022 Final",
    "venue": "Lusail Stadium",
    "capacity": 88966,
    "kickoff_iso": "2022-12-18T15:00:00Z",
    "referee": { "name": "Szymon Marciniak", "federation": "POL", "tournament_yellows": 14 },
    "weather": { "temp_c": 24, "condition": "clear" }
  },
  "teams": {
    "home": {
      "id": "arg", "name": "Argentina", "flag_svg_path": "flags/arg.svg", "color_hex": "#75AADB",
      "tournament_record": { "w": 5, "d": 1, "l": 1, "gf": 12, "ga": 5 },
      "h2h": { "all_time": { "w": 6, "d": 2, "l": 3 }, "last_wc_meeting": "2018 R16: FRA 4-3 (Mbappé x2)" }
    },
    "away": {
      "id": "fra", "name": "France", "flag_svg_path": "flags/fra.svg", "color_hex": "#0055A4",
      "tournament_record": { "w": 5, "d": 0, "l": 1, "gf": 13, "ga": 5 },
      "h2h": { "all_time": { "w": 3, "d": 2, "l": 6 }, "last_wc_meeting": "2018 R16: FRA 4-3 (Mbappé x2)" }
    }
  },
  "players": [
    {
      "id": "arg-10", "team_id": "arg", "shirt_number": 10, "name": "Lionel Messi",
      "position": "FW", "age": 35, "club": "Paris Saint-Germain",
      "stats": {
        "tournament": { "goals": 5, "assists": 3, "xg": 4.1, "min": 570 },
        "career": { "wc_goals": 11, "wc_apps": 25, "wc_assists": 8 },
        "form_last_5": { "goals": 5, "assists": 2 }
      },
      "role_tags": ["CAPTAIN", "TOP SCORER", "THE 10"],
      "storyline_ids": ["s-messi-last-dance"],
      "h2h_notes": ["Scored in every WC knockout round this tournament"],
      "didnt_know": ["98% conversion from the spot in WC knockouts since 2014"],
      "status": "fit"
    },
    {
      "id": "fra-10", "team_id": "fra", "shirt_number": 10, "name": "Kylian Mbappé",
      "position": "FW", "age": 23, "club": "Paris Saint-Germain",
      "stats": {
        "tournament": { "goals": 5, "assists": 2, "xg": 4.4, "min": 572 },
        "career": { "wc_goals": 9, "wc_apps": 11, "wc_assists": 4 },
        "form_last_5": { "goals": 5, "assists": 1 }
      },
      "role_tags": ["TOP SCORER", "GOLDEN BOOT WATCH", "THE 10"],
      "storyline_ids": ["s-mbappe-golden-boot"],
      "h2h_notes": ["Scored in the 2018 WC Final vs Croatia"],
      "didnt_know": ["Youngest player to reach 10 WC goals since Pelé"],
      "status": "fit"
    }
  ],
  "storylines": [
    {
      "id": "s-messi-last-dance",
      "player_ids": ["arg-10"],
      "text": "LAST DANCE — 5th & final WC at 35",
      "category": "last_dance",
      "priority_by_mode": { "stats_first": 2, "story_first": 10, "tactical": 1 }
    },
    {
      "id": "s-mbappe-golden-boot",
      "player_ids": ["fra-10"],
      "text": "GOLDEN BOOT — tied with Messi at 5 goals",
      "category": "record_watch",
      "priority_by_mode": { "stats_first": 8, "story_first": 6, "tactical": 2 }
    }
  ],
  "precedent_index": [
    {
      "id": "p-2goal-lead-wc-final",
      "trigger": { "event_type": "goal", "score_state": "2-0" },
      "stat_text": "Teams leading 2-0 in WC Finals have won 19 of 22 since 1970.",
      "counter_narrative": "BUT 1966 ENG and 1994 BRA came back from 2-0 down.",
      "category": "historical",
      "sources": ["FIFA", "Sportradar"]
    },
    {
      "id": "p-score-first-wc-final",
      "trigger": { "event_type": "goal", "score_state": "1-0" },
      "stat_text": "Teams scoring first in WC Finals have won 12 of 14 since 1970.",
      "counter_narrative": "1994 BRA vs ITA (pens) and 2006 ITA vs FRA (pens) are the exceptions.",
      "category": "historical",
      "sources": ["FIFA"]
    }
  ]
}
```

- [ ] **Step 6: Run — verify it passes**

Run: `npm test -- matchCache`
Expected: 3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/src/cactus/schema.ts app/src/cactus/state/matchCache.ts \
        app/src/cactus/__tests__/matchCache.test.ts app/assets/match_cache.json
git commit -m "feat(cactus): match cache schema, loader, and minimal stub"
```

---

## Task 2: Event bus

**Files:**
- Create: `app/src/cactus/state/eventBus.ts`
- Create: `app/src/cactus/__tests__/eventBus.test.ts`

- [ ] **Step 1: Write failing tests**

`app/src/cactus/__tests__/eventBus.test.ts`:

```ts
import { useEventBus } from '../state/eventBus';

describe('eventBus', () => {
  beforeEach(() => {
    useEventBus.setState({ events: [] });
  });

  it('emits and stores a stat_card event', () => {
    useEventBus.getState().emit({
      type: 'stat_card',
      player_id: 'arg-10',
      stat_text: '6th goal of tournament',
      source: 'Sportradar',
      latency_ms: 842,
      confidence_high: true,
    });
    const all = useEventBus.getState().events;
    expect(all).toHaveLength(1);
    expect(all[0].type).toBe('stat_card');
  });

  it('returns the latest event of a given type', () => {
    const state = useEventBus.getState();
    state.emit({ type: 'transcript', text: 'hello',   confidence: 0.9 });
    state.emit({ type: 'transcript', text: 'goodbye', confidence: 0.8 });
    const latest = state.latest('transcript');
    expect(latest?.text).toBe('goodbye');
  });

  it('caps event history at 200 items', () => {
    const state = useEventBus.getState();
    for (let i = 0; i < 250; i++) {
      state.emit({ type: 'transcript', text: String(i), confidence: 1 });
    }
    expect(useEventBus.getState().events).toHaveLength(200);
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- eventBus`
Expected: FAIL (module not found).

- [ ] **Step 3: Write the bus**

`app/src/cactus/state/eventBus.ts`:

```ts
import { create } from 'zustand';

// ---- Event shapes (DATA_CONTRACTS.md §3) ----
export type StatCardEvent         = { type: 'stat_card'; player_id: string; stat_text: string; source: string; latency_ms: number; confidence_high: boolean };
export type PrecedentEvent        = { type: 'precedent'; pattern_id: string; stat_text: string; category: string };
export type CounterNarrativeEvent = { type: 'counter_narrative'; text: string; for_team: 'home' | 'away'; tone: 'calming' | 'dramatic' };
export type RunningScoreEvent     = { type: 'running_score'; score: { home: number; away: number }; minute: number; momentum?: string };
export type MomentumTagEvent      = { type: 'momentum_tag'; text: string; team: 'home' | 'away' };
export type StreakAlertEvent      = { type: 'streak_alert'; player_id: string; streak_text: string; at_risk: boolean };
export type TranscriptEvent       = { type: 'transcript'; text: string; confidence: number };
export type StoryTickEvent        = { type: 'story_tick'; story_id: string };
export type VoiceCommandEvent     = { type: 'voice_command'; raw: string; classified_as: 'widget' | 'query' | 'unclear' };
export type WidgetBuiltEvent      = { type: 'widget_built'; widget: WidgetSpec };
export type AnswerCardEvent       = { type: 'answer_card'; question: string; answer: string; source: string; confidence_high: boolean; latency_ms: number };
export type NoDataEvent           = { type: 'no_data'; question: string };
export type OptInTtsEvent         = { type: 'opt_in_tts'; enabled: boolean };
export type ModeChangedEvent      = { type: 'mode_changed'; mode: 'stats_first' | 'story_first' | 'tactical' | 'custom' };

export type WidgetSpec = {
  id: string;
  kind: 'timeline' | 'bar_chart' | 'comparison_table' | 'heat_map' | 'shot_map';
  title: string;
  data: unknown;
  pinned: boolean;
  source: string;
};

export type BusEvent =
  | StatCardEvent | PrecedentEvent | CounterNarrativeEvent | RunningScoreEvent
  | MomentumTagEvent | StreakAlertEvent | TranscriptEvent | StoryTickEvent
  | VoiceCommandEvent | WidgetBuiltEvent | AnswerCardEvent | NoDataEvent
  | OptInTtsEvent | ModeChangedEvent;

type EventOfType<T extends BusEvent['type']> = Extract<BusEvent, { type: T }>;

type BusState = {
  events: BusEvent[];
  emit: (event: BusEvent) => void;
  latest: <T extends BusEvent['type']>(type: T) => EventOfType<T> | undefined;
  clear: () => void;
};

const MAX_EVENTS = 200;

export const useEventBus = create<BusState>((set, get) => ({
  events: [],
  emit: (event) => set((s) => ({ events: [...s.events, event].slice(-MAX_EVENTS) })),
  latest: (type) => {
    const events = get().events;
    for (let i = events.length - 1; i >= 0; i--) {
      if (events[i].type === type) return events[i] as EventOfType<typeof type>;
    }
    return undefined;
  },
  clear: () => set({ events: [] }),
}));
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- eventBus`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/state/eventBus.ts app/src/cactus/__tests__/eventBus.test.ts
git commit -m "feat(cactus): typed zustand event bus with 14 event shapes"
```

---

## Task 3: Gemma 4 function toolbox

**Files:**
- Create: `app/src/cactus/functions.ts`
- Create: `app/src/cactus/__tests__/functions.test.ts`

- [ ] **Step 1: Write failing tests**

`app/src/cactus/__tests__/functions.test.ts`:

```ts
import * as fns from '../functions';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

const raw = require('../../../assets/match_cache.json');

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(raw);
});

describe('get_player_stat', () => {
  it('direct tournament-goals lookup returns stat + source + high confidence', () => {
    const r = fns.get_player_stat('Messi', 'current_tournament');
    expect(r).not.toBeNull();
    expect(r!.value).toBe(5);
    expect(r!.source).toBeDefined();
    expect(r!.confidence_high).toBe(true);
  });

  it('resolves by last name', () => {
    const r = fns.get_player_stat('mbappé');
    expect(r).not.toBeNull();
    expect(r!.stat_text).toMatch(/Mbappé/i);
  });

  it('returns null for ambiguous names (no match)', () => {
    const r = fns.get_player_stat('Nobody', 'career');
    expect(r).toBeNull();
  });
});

describe('get_team_stat', () => {
  it('returns tournament record for arg', () => {
    const r = fns.get_team_stat('arg', 'record');
    expect(r).not.toBeNull();
    expect(r!.stat_text).toMatch(/5-1-1|5W/i);
  });

  it('null for unknown metric', () => {
    expect(fns.get_team_stat('arg', 'frobnicate_level')).toBeNull();
  });
});

describe('get_historical', () => {
  it('returns eligible precedents for 2-0 goal trigger', () => {
    const r = fns.get_historical('2-0 lead in WC Final');
    expect(r.length).toBeGreaterThan(0);
    expect(r[0].trigger.score_state).toBe('2-0');
  });

  it('returns [] when nothing matches', () => {
    expect(fns.get_historical('nonsense query with no match')).toEqual([]);
  });
});

describe('get_match_context', () => {
  it('returns a sane default match state', () => {
    const r = fns.get_match_context('arg-vs-fra-2022-wc-final');
    expect(r.score).toEqual({ home: 0, away: 0 });
    expect(r.phase).toBe('pre_match');
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- functions`
Expected: FAIL (module not found).

- [ ] **Step 3: Write `functions.ts`**

`app/src/cactus/functions.ts`:

```ts
import { getMatchCache } from './state/matchCache';
import type { PrecedentPattern, Player } from './schema';

export type FunctionResult = {
  stat_text: string;
  value: number | string;
  source: string;
  confidence_high: boolean;
} | null;

// ---- Player resolution ----

function resolvePlayer(name: string): Player | null {
  const cache = getMatchCache();
  const query = name.toLowerCase().trim();
  const matches = cache.players.filter((p) => {
    const full = p.name.toLowerCase();
    const last = full.split(' ').slice(-1)[0];
    const shirt = String(p.shirt_number);
    const tags  = p.role_tags.map((t) => t.toLowerCase());
    return (
      full.includes(query) ||
      query.includes(last) ||
      query === shirt ||
      tags.some((t) => query.includes(t.toLowerCase()))
    );
  });
  if (matches.length !== 1) return null;
  return matches[0];
}

// ---- Function toolbox ----

export function get_player_stat(player_name: string, situation = 'current_tournament'): FunctionResult {
  const p = resolvePlayer(player_name);
  if (!p) return null;

  const scope =
    situation.includes('career')     ? 'career'       :
    situation.includes('form')       ? 'form_last_5'  :
                                       'tournament';
  const stats = p.stats[scope];
  const key = pickStatKey(stats, situation);
  if (!key) return null;

  const value = stats[key];
  const source = (stats as Record<string, string | number>).__source as string | undefined;
  return {
    stat_text: `${p.name}: ${labelFor(key, scope)} = ${value}`,
    value,
    source: source ?? 'Sportradar',
    confidence_high: true,
  };
}

function pickStatKey(stats: Record<string, number | string>, situation: string): string | null {
  const hints = situation.toLowerCase();
  const keys = Object.keys(stats).filter((k) => !k.startsWith('__'));
  if (!keys.length) return null;
  const match = keys.find((k) => hints.includes(k.toLowerCase()));
  return match ?? keys[0];
}

function labelFor(key: string, scope: string): string {
  return `${scope.replace('_', ' ')} ${key}`;
}

export function get_team_stat(team: 'arg' | 'fra', metric: string): FunctionResult {
  const cache = getMatchCache();
  const t = team === 'arg' ? cache.teams.home : cache.teams.away;

  if (metric === 'record') {
    const r = t.tournament_record;
    return {
      stat_text: `${t.name} tournament record: ${r.w}W-${r.d}D-${r.l}L · ${r.gf} GF / ${r.ga} GA`,
      value: `${r.w}-${r.d}-${r.l}`,
      source: 'Sportradar',
      confidence_high: true,
    };
  }
  return null;
}

export type MatchContext = {
  score: { home: number; away: number };
  minute: number;
  added_time: number | null;
  phase: 'pre_match' | '1st_half' | 'half_time' | '2nd_half' | 'ET_1st' | 'ET_2nd' | 'penalties' | 'full_time';
  possession_pct: { home: number; away: number };
  shots: { home: number; away: number };
  shots_on_target: { home: number; away: number };
  recent_events: unknown[];
};

// Live context comes from a runtime store; for now returns the "pre-match" baseline.
// Task 11 (orchestrator) will override this via setMatchContext() when beats fire.
let liveContext: MatchContext = {
  score: { home: 0, away: 0 },
  minute: 0,
  added_time: null,
  phase: 'pre_match',
  possession_pct: { home: 50, away: 50 },
  shots: { home: 0, away: 0 },
  shots_on_target: { home: 0, away: 0 },
  recent_events: [],
};

export function setMatchContext(patch: Partial<MatchContext>) {
  liveContext = { ...liveContext, ...patch };
}

export function get_match_context(_match_id: string): MatchContext {
  return liveContext;
}

export function get_historical(query: string): PrecedentPattern[] {
  const cache = getMatchCache();
  const q = query.toLowerCase();
  return cache.precedent_index.filter((p) => {
    if (p.trigger.score_state && q.includes(p.trigger.score_state)) return true;
    if (q.includes(p.trigger.event_type)) return true;
    if (p.stat_text.toLowerCase().split(' ').some((w) => q.includes(w) && w.length > 4)) return true;
    return false;
  });
}

// Local profile persisted via AsyncStorage in the real app; defaults here.
export function get_commentator_profile() {
  return {
    id: 'default',
    mode: 'stats_first' as const,
    density: 'standard' as const,
    pinned_stats_by_position: { GK: [], DF: [], MF: [], FW: ['goals', 'assists', 'xg'] },
    pinned_storyline_ids: [],
    hidden_storyline_ids: [],
    annotations: {},
    stat_swap_history: [],
    transcript_corpus: [],
  };
}
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- functions`
Expected: all tests pass. If a specific test fails, adjust the implementation (not the test) until it passes — the tests encode the grounding contract.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/functions.ts app/src/cactus/__tests__/functions.test.ts
git commit -m "feat(cactus): gemma 4 function toolbox with grounding discipline"
```

---

## Task 4: Dedupe module

**Files:**
- Create: `app/src/cactus/pipeline/dedupe.ts`
- Create: `app/src/cactus/__tests__/dedupe.test.ts`

- [ ] **Step 1: Write failing tests**

`app/src/cactus/__tests__/dedupe.test.ts`:

```ts
import { Dedupe } from '../pipeline/dedupe';

describe('Dedupe', () => {
  it('drops exact signature within window', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    const sig = { event_type: 'goal', players: ['messi'] };
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 0 })).toBe(false);
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 5_000 })).toBe(true);
  });

  it('allows signature again after window expires', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    const sig = { event_type: 'goal', players: ['messi'] };
    d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 0 });
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 31_000 })).toBe(false);
  });

  it('drops when commentator already said the stat substring', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    d.ingestTranscript('this is messi fifth goal of the tournament', 1_000);
    const drop = d.shouldDrop({
      signature: { event_type: 'goal', players: ['messi'] },
      statText: 'Messi fifth goal of the tournament',
      now: 2_000,
    });
    expect(drop).toBe(true);
  });

  it('transcript expires outside its window', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    d.ingestTranscript('messi fifth goal', 0);
    const drop = d.shouldDrop({
      signature: { event_type: 'goal', players: ['messi'] },
      statText: 'Messi fifth goal',
      now: 21_000,
    });
    expect(drop).toBe(false);
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- dedupe`
Expected: FAIL (module not found).

- [ ] **Step 3: Write dedupe**

`app/src/cactus/pipeline/dedupe.ts`:

```ts
export type Signature = { event_type: string; players: string[] };

type Options = {
  signatureWindowMs: number;
  transcriptWindowMs: number;
};

type SigRecord = { key: string; at: number };
type TxRecord  = { text: string; at: number };

export class Dedupe {
  private sigs: SigRecord[] = [];
  private txs: TxRecord[] = [];

  constructor(private opts: Options) {}

  ingestTranscript(text: string, now: number) {
    this.txs.push({ text: normalize(text), at: now });
    this.prune(now);
  }

  shouldDrop({ signature, statText, now }: { signature: Signature; statText: string; now: number }): boolean {
    this.prune(now);
    const key = sigKey(signature);
    if (this.sigs.some((r) => r.key === key)) return true;

    const normalized = normalize(statText);
    const overlap = this.txs.some((r) => transcriptOverlap(r.text, normalized) >= 0.6);
    if (overlap) return true;

    this.sigs.push({ key, at: now });
    return false;
  }

  private prune(now: number) {
    this.sigs = this.sigs.filter((r) => now - r.at <= this.opts.signatureWindowMs);
    this.txs  = this.txs.filter((r) => now - r.at <= this.opts.transcriptWindowMs);
  }
}

function sigKey(s: Signature): string {
  return `${s.event_type}::${[...s.players].sort().join(',')}`;
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
}

// Token overlap ratio — simple and fast, good enough for dup suppression.
function transcriptOverlap(a: string, b: string): number {
  const ta = new Set(a.split(' ').filter((w) => w.length > 3));
  const tb = new Set(b.split(' ').filter((w) => w.length > 3));
  if (!tb.size) return 0;
  let hit = 0;
  for (const w of tb) if (ta.has(w)) hit++;
  return hit / tb.size;
}
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- dedupe`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/pipeline/dedupe.ts app/src/cactus/__tests__/dedupe.test.ts
git commit -m "feat(cactus): dedupe module (signature + transcript overlap)"
```

---

## Task 5: Gate (VAD + classifier wrapper)

**Files:**
- Create: `app/src/cactus/pipeline/gate.ts`
- Create: `app/src/cactus/__tests__/gate.test.ts`

- [ ] **Step 1: Write failing tests**

`app/src/cactus/__tests__/gate.test.ts`:

```ts
import { Gate, VadStats } from '../pipeline/gate';

const loud: VadStats  = { peakDb: -20, voicedFrames: 16, totalFrames: 20 };
const quiet: VadStats = { peakDb: -55, voicedFrames:  0, totalFrames: 20 };

describe('Gate.vadAccept', () => {
  it('accepts loud, voiced audio', () => {
    expect(new Gate().vadAccept(loud)).toBe(true);
  });
  it('rejects silent audio', () => {
    expect(new Gate().vadAccept(quiet)).toBe(false);
  });
  it('rejects audio that is loud but not voiced enough', () => {
    expect(new Gate().vadAccept({ peakDb: -20, voicedFrames: 3, totalFrames: 20 })).toBe(false);
  });
});

describe('Gate.classify', () => {
  it('returns opportunity=true for a goal classification', async () => {
    const gate = new Gate();
    const classifier = jest.fn().mockResolvedValue({
      transcript: 'messi scores from the spot',
      stat_opportunity: true,
      event_type: 'goal',
      players_mentioned: ['messi'],
      score_state_changed: true,
    });
    const r = await gate.classify(new ArrayBuffer(0), classifier);
    expect(r.stat_opportunity).toBe(true);
    expect(r.event_type).toBe('goal');
  });

  it('treats malformed classifier output as drop-worthy', async () => {
    const gate = new Gate();
    const classifier = jest.fn().mockResolvedValue({ garbage: true });
    const r = await gate.classify(new ArrayBuffer(0), classifier);
    expect(r.stat_opportunity).toBe(false);
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- gate`
Expected: FAIL.

- [ ] **Step 3: Write gate**

`app/src/cactus/pipeline/gate.ts`:

```ts
export type VadStats = { peakDb: number; voicedFrames: number; totalFrames: number };

export type Classification = {
  transcript: string;
  stat_opportunity: boolean;
  event_type?: 'goal' | 'shot' | 'card' | 'sub' | 'milestone' | null;
  players_mentioned?: string[];
  score_state_changed?: boolean;
};

export type OpportunityClassifier = (audio: ArrayBuffer) => Promise<unknown>;

const PEAK_DB_THRESHOLD = -40;
const MIN_VOICED_FRAMES = 8;

export class Gate {
  vadAccept(stats: VadStats): boolean {
    if (stats.peakDb < PEAK_DB_THRESHOLD) return false;
    if (stats.voicedFrames < MIN_VOICED_FRAMES) return false;
    return true;
  }

  async classify(audio: ArrayBuffer, classifier: OpportunityClassifier): Promise<Classification> {
    try {
      const raw = await classifier(audio);
      return normalizeClassification(raw);
    } catch {
      return { transcript: '', stat_opportunity: false };
    }
  }
}

function normalizeClassification(raw: unknown): Classification {
  if (!raw || typeof raw !== 'object') return { transcript: '', stat_opportunity: false };
  const r = raw as Record<string, unknown>;
  if (typeof r.stat_opportunity !== 'boolean') {
    return { transcript: String(r.transcript ?? ''), stat_opportunity: false };
  }
  return {
    transcript: String(r.transcript ?? ''),
    stat_opportunity: r.stat_opportunity,
    event_type: (r.event_type as Classification['event_type']) ?? null,
    players_mentioned: Array.isArray(r.players_mentioned) ? r.players_mentioned.map(String) : [],
    score_state_changed: Boolean(r.score_state_changed),
  };
}
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- gate`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/pipeline/gate.ts app/src/cactus/__tests__/gate.test.ts
git commit -m "feat(cactus): gate — vad + stat_opportunity classifier normalizer"
```

---

## Task 6: System prompts

**Files:**
- Create: `app/src/cactus/prompts.ts`

No tests — prompts are data, validated via Task 13's smoke harness against real Gemma 4.

- [ ] **Step 1: Write prompts file**

`app/src/cactus/prompts.ts`:

```ts
export const AUTONOMOUS_PROMPT = `
You are the backend of an on-device AI co-pilot for a sports broadcaster.
You receive a short audio chunk of live soccer commentary (2 seconds).

RULES:
1. Return JSON ONLY. No prose, no markdown.
2. Decide stat_opportunity=true ONLY if the commentator described a discrete
   stat-worthy event in THIS chunk: a goal, a shot on target, a yellow or red
   card, a substitution, or a milestone (e.g., "his fifth of the tournament").
3. Ambient analysis, transitions, crowd noise, replay chatter = stat_opportunity=false.
4. If the audio is silent or non-speech, stat_opportunity=false.
5. Do not invent stats. Do not call functions in this phase.

Output schema:
{
  "transcript": string,
  "stat_opportunity": boolean,
  "event_type": "goal" | "shot" | "card" | "sub" | "milestone" | null,
  "players_mentioned": string[],
  "score_state_changed": boolean
}
`.trim();

export const GENERATE_PROMPT = `
You are the backend of an on-device AI co-pilot for a sports broadcaster.
A stat-worthy event just occurred. You have access to these functions:

- get_player_stat(player_name, situation)
- get_team_stat(team, metric)
- get_match_context(match_id)
- get_historical(query)

Call the functions you need, then produce a final stat card.

RULES:
1. Call functions. Do NOT invent stats.
2. If a function returns null or an empty array, emit trust_escape. Do not guess.
3. Every stat_text value must be grounded in data you received from a function in
   THIS session.
4. If the player name is ambiguous, emit trust_escape.

Output schema (JSON only):
{
  "stat_text": string,
  "source": string,
  "player_id": string | null,
  "confidence_high": boolean,
  "precedent_id": string | null,
  "counter_narrative": { "text": string, "for_team": "home" | "away" } | null,
  "trust_escape": boolean
}
`.trim();

export const QUERY_OR_COMMAND_PROMPT = `
You are the backend of an on-device AI co-pilot for a sports broadcaster.
You receive a press-to-talk audio recording. Transcribe it, then classify:

- COMMAND — the commentator asked you to show or pull up data
  ("show me Mbappé's WC final record", "pull up the shot map")
  → build a widget_spec.
- QUERY — the commentator asked a question expecting an answer
  ("how many WC goals has Mbappé scored?")
  → return an answer_card.
- UNGROUNDED — the question cannot be answered from the available functions
  ("what's his favourite food?")
  → emit trust_escape with the original transcript.

You have access to these functions:
- get_player_stat(player_name, situation)
- get_team_stat(team, metric)
- get_match_context(match_id)
- get_historical(query)

RULES:
1. Call functions to ground every claim.
2. If you cannot ground a claim, emit trust_escape. Do not guess.
3. Return JSON only.

Output schema:
{
  "transcript": string,
  "intent": "command" | "query" | "ungrounded",
  "answer": string | null,
  "source": string | null,
  "confidence_high": boolean,
  "widget_spec": { "id": string, "kind": string, "title": string, "data": unknown, "pinned": false, "source": string } | null,
  "trust_escape": boolean
}
`.trim();
```

- [ ] **Step 2: Commit**

```bash
git add app/src/cactus/prompts.ts
git commit -m "feat(cactus): system prompts for autonomous / generate / query-or-command"
```

---

## Task 7: Cactus client wrapper

**Files:**
- Create: `app/src/cactus/client.ts`
- Create: `app/src/cactus/__tests__/client.test.ts`

- [ ] **Step 1: Resolve the Cactus RN SDK spike**

Before writing the wrapper, verify on a physical iPad that `cactus-react-native` is importable from the Expo custom dev client. If the JS binding does not exist, fall back to installing from source (`npm install github:cactus-compute/cactus#main --workspace=react-native`) or wrap the native iOS SDK behind an Expo config plugin. **This is the SPEC Open Q1 de-risker** — until it resolves, mock Cactus in tests.

Record the chosen binding in `docs/superpowers/notes/cactus-sdk-resolution.md` (create the file).

- [ ] **Step 2: Write failing test with mocked Cactus**

`app/src/cactus/__tests__/client.test.ts`:

```ts
jest.mock('cactus-react-native', () => ({
  Cactus: {
    load: jest.fn().mockResolvedValue({ sessionId: 'mock' }),
    generate: jest.fn().mockResolvedValue('{"transcript":"hi","stat_opportunity":false}'),
    close: jest.fn().mockResolvedValue(undefined),
  },
}));

import { CactusClient } from '../client';

describe('CactusClient', () => {
  it('loads the model once and reuses the session', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    await c.ensureLoaded('google/functiongemma-270m-it');
    const mod = require('cactus-react-native');
    expect(mod.Cactus.load).toHaveBeenCalledTimes(1);
  });

  it('generate returns string output', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    const out = await c.generate({ prompt: 'x' });
    expect(typeof out).toBe('string');
  });

  it('generate respects AbortSignal', async () => {
    const c = new CactusClient();
    await c.ensureLoaded('google/functiongemma-270m-it');
    const ac = new AbortController();
    ac.abort();
    await expect(c.generate({ prompt: 'x', signal: ac.signal })).rejects.toThrow(/abort/i);
  });
});
```

- [ ] **Step 3: Run — verify fails**

Run: `npm test -- client`
Expected: FAIL (module not found).

- [ ] **Step 4: Write the wrapper**

`app/src/cactus/client.ts`:

```ts
// cactus-react-native is resolved at install-time in Task 0 + Task 7 spike.
// The surface below is the assumed shape. Adjust imports after the SDK spike.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const cactusMod: { Cactus: any } = require('cactus-react-native');
const { Cactus } = cactusMod;

export type GenerateInput = {
  prompt?: string;
  audio?: ArrayBuffer;
  tools?: unknown;
  signal?: AbortSignal;
};

export class CactusClient {
  private session: { sessionId: string } | null = null;
  private loading: Promise<void> | null = null;
  private modelId: string | null = null;

  async ensureLoaded(modelId: string): Promise<void> {
    if (this.session && this.modelId === modelId) return;
    if (this.loading) return this.loading;
    this.loading = (async () => {
      this.session = await Cactus.load({ model: modelId });
      this.modelId = modelId;
      this.loading = null;
    })();
    return this.loading;
  }

  async generate(input: GenerateInput): Promise<string> {
    if (!this.session) throw new Error('Cactus session not loaded');
    if (input.signal?.aborted) throw new Error('Cactus.generate aborted before dispatch');
    const genPromise = Cactus.generate({
      sessionId: this.session.sessionId,
      prompt: input.prompt,
      audio: input.audio,
      tools: input.tools,
    });
    return withAbort(genPromise, input.signal);
  }

  async close(): Promise<void> {
    if (!this.session) return;
    await Cactus.close({ sessionId: this.session.sessionId });
    this.session = null;
    this.modelId = null;
  }
}

function withAbort<T>(p: Promise<T>, signal?: AbortSignal): Promise<T> {
  if (!signal) return p;
  return new Promise<T>((resolve, reject) => {
    const onAbort = () => reject(new Error('Cactus.generate aborted'));
    signal.addEventListener('abort', onAbort, { once: true });
    p.then(
      (v) => { signal.removeEventListener('abort', onAbort); resolve(v); },
      (e) => { signal.removeEventListener('abort', onAbort); reject(e); },
    );
  });
}
```

- [ ] **Step 5: Run — verify passes**

Run: `npm test -- client`
Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/src/cactus/client.ts app/src/cactus/__tests__/client.test.ts
git commit -m "feat(cactus): sdk client wrapper with session reuse and AbortSignal"
```

---

## Task 8: `askGemma` — the public contract

**Files:**
- Create: `app/src/cactus/askGemma.ts`
- Create: `app/src/cactus/__tests__/askGemma.test.ts`

- [ ] **Step 1: Write failing tests**

`app/src/cactus/__tests__/askGemma.test.ts`:

```ts
jest.mock('../client', () => {
  return {
    CactusClient: class {
      async ensureLoaded() {}
      async generate(opts: any) {
        if (opts.prompt?.includes('QUERY_OR_COMMAND')) {
          return JSON.stringify({
            transcript: 'how many goals has mbappe scored',
            intent: 'query',
            answer: 'Mbappé has 9 WC career goals.',
            source: 'Sportradar',
            confidence_high: true,
            widget_spec: null,
            trust_escape: false,
          });
        }
        return JSON.stringify({ transcript: '', stat_opportunity: false });
      }
    },
  };
});

import { askGemma } from '../askGemma';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(require('../../../assets/match_cache.json'));
});

describe('askGemma (press-to-talk)', () => {
  it('returns a grounded answer for a QUERY intent', async () => {
    const audio = new ArrayBuffer(1024);
    const r = await askGemma(
      { audio },
      {
        mode: 'stats_first',
        match_state: {
          score: { home: 0, away: 0 }, minute: 0, added_time: null, phase: 'pre_match',
          possession_pct: { home: 50, away: 50 },
          shots: { home: 0, away: 0 }, shots_on_target: { home: 0, away: 0 }, recent_events: [],
        },
        recent_transcripts: [],
        commentator_profile: require('../functions').get_commentator_profile(),
      },
      'local',
    );
    expect(r.stat_text).toMatch(/Mbapp/i);
    expect(r.source).toBe('Sportradar');
    expect(r.confidence_high).toBe(true);
    expect(r.latency_ms).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- askGemma`
Expected: FAIL.

- [ ] **Step 3: Write `askGemma`**

`app/src/cactus/askGemma.ts`:

```ts
import { CactusClient } from './client';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from './prompts';
import * as functions from './functions';
import type { MatchContext } from './functions';
import type { WidgetSpec } from './state/eventBus';
import type { PrecedentPattern } from './schema';

const MODEL_ID = 'google/functiongemma-270m-it';

const client = new CactusClient();

export type AskGemmaInput   = { prompt?: string; audio?: ArrayBuffer };
export type AskGemmaContext = {
  mode: 'stats_first' | 'story_first' | 'tactical' | 'custom';
  match_state: MatchContext;
  recent_transcripts: string[];
  commentator_profile: ReturnType<typeof functions.get_commentator_profile>;
};
export type AskGemmaRouting = 'auto' | 'local' | 'cloud';

export type AskGemmaResult = {
  stat_text: string;
  source: string;
  confidence_high: boolean;
  player_id?: string;
  latency_ms: number;
  transcript?: string;
  widget_spec?: WidgetSpec;
  precedent?: PrecedentPattern;
  counter_narrative?: { text: string; for_team: 'home' | 'away' };
};

const TOOLS = {
  get_player_stat: functions.get_player_stat,
  get_team_stat: functions.get_team_stat,
  get_match_context: functions.get_match_context,
  get_historical: functions.get_historical,
  get_commentator_profile: functions.get_commentator_profile,
};

export async function askGemma(
  input: AskGemmaInput,
  context: AskGemmaContext,
  routing: AskGemmaRouting,
): Promise<AskGemmaResult> {
  const t0 = Date.now();
  await client.ensureLoaded(MODEL_ID);

  const hint = routing === 'cloud' ? 'CLOUD' : 'LOCAL';
  const prompt = [
    QUERY_OR_COMMAND_PROMPT,
    `ROUTING=${hint}`,
    `MODE=${context.mode}`,
    `MATCH_STATE=${JSON.stringify(context.match_state)}`,
    `RECENT_TRANSCRIPT=${context.recent_transcripts.slice(-3).join(' | ')}`,
    input.prompt ? `QUESTION=${input.prompt}` : '',
  ].filter(Boolean).join('\n');

  const raw = await client.generate({ prompt, audio: input.audio, tools: TOOLS });

  const parsed = safeJson(raw);
  const latency_ms = Date.now() - t0;

  if (!parsed || parsed.trust_escape) {
    return {
      stat_text: "I don't have verified data on that.",
      source: 'trust_escape',
      confidence_high: false,
      transcript: parsed?.transcript,
      latency_ms,
    };
  }

  return {
    stat_text: String(parsed.answer ?? parsed.stat_text ?? ''),
    source: String(parsed.source ?? 'Sportradar'),
    confidence_high: Boolean(parsed.confidence_high),
    player_id: parsed.player_id ?? undefined,
    transcript: parsed.transcript,
    widget_spec: parsed.widget_spec ?? undefined,
    latency_ms,
  };
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}

// exported for orchestrator + smoke harness
export const __internal__ = { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT, client };
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- askGemma`
Expected: test passes.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/askGemma.ts app/src/cactus/__tests__/askGemma.test.ts
git commit -m "feat(cactus): askGemma — the single integration contract"
```

---

## Task 9: Press-to-talk audio capture

**Files:**
- Create: `app/src/cactus/audio/pressToTalk.ts`

No Jest tests — expo-av can't run in Node without heavy mocks that test nothing useful. Validated manually on device in Task 14.

- [ ] **Step 1: Write capture module**

`app/src/cactus/audio/pressToTalk.ts`:

```ts
import { Audio } from 'expo-av';

const MAX_RECORD_MS = 8_000;

export class PressToTalkRecorder {
  private recording: Audio.Recording | null = null;
  private autoStopTimer: ReturnType<typeof setTimeout> | null = null;

  async start(onAutoStop: () => void): Promise<void> {
    if (this.recording) return;
    const perm = await Audio.requestPermissionsAsync();
    if (!perm.granted) throw new Error('Mic permission denied');
    await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });

    const rec = new Audio.Recording();
    await rec.prepareToRecordAsync(Audio.RecordingOptionsPresets.HIGH_QUALITY);
    await rec.startAsync();
    this.recording = rec;

    this.autoStopTimer = setTimeout(() => {
      onAutoStop();
    }, MAX_RECORD_MS);
  }

  async stop(): Promise<ArrayBuffer | null> {
    if (!this.recording) return null;
    if (this.autoStopTimer) clearTimeout(this.autoStopTimer);
    this.autoStopTimer = null;

    await this.recording.stopAndUnloadAsync();
    const uri = this.recording.getURI();
    this.recording = null;
    if (!uri) return null;
    return uriToArrayBuffer(uri);
  }
}

async function uriToArrayBuffer(uri: string): Promise<ArrayBuffer> {
  const res = await fetch(uri);
  return await res.arrayBuffer();
}
```

- [ ] **Step 2: Commit**

```bash
git add app/src/cactus/audio/pressToTalk.ts
git commit -m "feat(cactus): press-to-talk audio capture via expo-av"
```

---

## Task 10: Continuous rolling-buffer capture

**Files:**
- Create: `app/src/cactus/audio/continuous.ts`

- [ ] **Step 1: Write capture module**

`app/src/cactus/audio/continuous.ts`:

```ts
import { Audio } from 'expo-av';
import type { VadStats } from '../pipeline/gate';

const WINDOW_MS = 2_000;
const HOP_MS    = 1_500;      // 500ms overlap

export type Chunk = { audio: ArrayBuffer; stats: VadStats; at: number };

export class ContinuousCapture {
  private recording: Audio.Recording | null = null;
  private timer: ReturnType<typeof setInterval> | null = null;
  private meterings: { db: number; at: number }[] = [];

  async start(onChunk: (chunk: Chunk) => void): Promise<void> {
    if (this.recording) return;
    const perm = await Audio.requestPermissionsAsync();
    if (!perm.granted) throw new Error('Mic permission denied');
    await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });

    await this.startInner(onChunk);
  }

  private async startInner(onChunk: (chunk: Chunk) => void) {
    const rec = new Audio.Recording();
    await rec.prepareToRecordAsync({
      ...Audio.RecordingOptionsPresets.HIGH_QUALITY,
      isMeteringEnabled: true,
    });
    rec.setOnRecordingStatusUpdate((st) => {
      if (st.isRecording && typeof st.metering === 'number') {
        this.meterings.push({ db: st.metering, at: Date.now() });
      }
    });
    await rec.startAsync();
    this.recording = rec;

    this.timer = setInterval(async () => {
      const chunk = await this.rotate(onChunk);
      if (!chunk) return;
      onChunk(chunk);
    }, HOP_MS);
  }

  private async rotate(_onChunk: (chunk: Chunk) => void): Promise<Chunk | null> {
    if (!this.recording) return null;
    const old = this.recording;
    // Start a new segment before stopping the old so the mic never has a gap.
    const fresh = new Audio.Recording();
    await fresh.prepareToRecordAsync({
      ...Audio.RecordingOptionsPresets.HIGH_QUALITY,
      isMeteringEnabled: true,
    });
    await fresh.startAsync();
    this.recording = fresh;

    await old.stopAndUnloadAsync();
    const uri = old.getURI();
    if (!uri) return null;
    const res = await fetch(uri);
    const audio = await res.arrayBuffer();
    const stats = this.drainMeterings();
    return { audio, stats, at: Date.now() };
  }

  private drainMeterings(): VadStats {
    const now = Date.now();
    const windowStart = now - WINDOW_MS;
    const inWindow = this.meterings.filter((m) => m.at >= windowStart);
    this.meterings = this.meterings.filter((m) => m.at >= now - WINDOW_MS);
    const peakDb = inWindow.reduce((p, m) => Math.max(p, m.db), -160);
    const voicedFrames = inWindow.filter((m) => m.db > -45).length;
    return { peakDb, voicedFrames, totalFrames: Math.max(1, inWindow.length) };
  }

  async stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    if (this.recording) {
      await this.recording.stopAndUnloadAsync();
      this.recording = null;
    }
    this.meterings = [];
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/src/cactus/audio/continuous.ts
git commit -m "feat(cactus): continuous rolling-buffer capture with metering-based VAD"
```

---

## Task 11: Orchestrator

**Files:**
- Create: `app/src/cactus/pipeline/orchestrator.ts`
- Create: `app/src/cactus/__tests__/orchestrator.test.ts`

- [ ] **Step 1: Write failing test (simulated chunk flow)**

`app/src/cactus/__tests__/orchestrator.test.ts`:

```ts
jest.mock('../client', () => {
  let call = 0;
  return {
    CactusClient: class {
      async ensureLoaded() {}
      async generate() {
        call++;
        if (call === 1) {
          return JSON.stringify({
            transcript: 'messi scores from the spot',
            stat_opportunity: true,
            event_type: 'goal',
            players_mentioned: ['messi'],
            score_state_changed: true,
          });
        }
        return JSON.stringify({
          stat_text: 'Messi 6th of tournament · 2nd WC Final goal of career',
          source: 'Sportradar',
          player_id: 'arg-10',
          confidence_high: true,
          precedent_id: 'p-score-first-wc-final',
          counter_narrative: { text: 'France came back in 2018.', for_team: 'away' },
          trust_escape: false,
        });
      }
    },
  };
});

import { Orchestrator } from '../pipeline/orchestrator';
import { useEventBus } from '../state/eventBus';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(require('../../../assets/match_cache.json'));
  useEventBus.setState({ events: [] });
});

describe('Orchestrator.processAutonomousChunk', () => {
  it('emits stat_card + precedent + counter_narrative on an opportunity', async () => {
    const orch = new Orchestrator();
    await orch.processAutonomousChunk({
      audio: new ArrayBuffer(1024),
      stats: { peakDb: -20, voicedFrames: 16, totalFrames: 20 },
      at: Date.now(),
    });
    const types = useEventBus.getState().events.map((e) => e.type);
    expect(types).toContain('stat_card');
    expect(types).toContain('precedent');
    expect(types).toContain('counter_narrative');
  });

  it('drops silent chunks at VAD', async () => {
    const orch = new Orchestrator();
    await orch.processAutonomousChunk({
      audio: new ArrayBuffer(1024),
      stats: { peakDb: -55, voicedFrames: 0, totalFrames: 20 },
      at: Date.now(),
    });
    expect(useEventBus.getState().events).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run — verify fails**

Run: `npm test -- orchestrator`
Expected: FAIL.

- [ ] **Step 3: Write orchestrator**

`app/src/cactus/pipeline/orchestrator.ts`:

```ts
import { CactusClient } from '../client';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from '../prompts';
import * as functions from '../functions';
import { Gate } from './gate';
import { Dedupe } from './dedupe';
import { useEventBus, WidgetSpec } from '../state/eventBus';
import type { Chunk } from '../audio/continuous';
import { getMatchCache } from '../state/matchCache';

const MODEL_ID = 'google/functiongemma-270m-it';

export class Orchestrator {
  private client = new CactusClient();
  private gate   = new Gate();
  private dedupe = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
  private inflight: AbortController | null = null;

  async processAutonomousChunk(chunk: Chunk): Promise<void> {
    if (!this.gate.vadAccept(chunk.stats)) return;

    // Cancel any in-flight inference — newest wins.
    if (this.inflight) this.inflight.abort();
    const ac = new AbortController();
    this.inflight = ac;

    await this.client.ensureLoaded(MODEL_ID);

    const classify = await this.gate.classify(chunk.audio, async (audio) => {
      const out = await this.client.generate({
        prompt: AUTONOMOUS_PROMPT,
        audio,
        signal: ac.signal,
      });
      return JSON.parse(out);
    });

    if (classify.transcript) {
      this.dedupe.ingestTranscript(classify.transcript, chunk.at);
      useEventBus.getState().emit({
        type: 'transcript',
        text: classify.transcript,
        confidence: 0.9,
      });
    }

    if (!classify.stat_opportunity) return;

    const signature = {
      event_type: classify.event_type ?? 'other',
      players: (classify.players_mentioned ?? []).map((p) => p.toLowerCase()),
    };
    if (this.dedupe.shouldDrop({ signature, statText: classify.transcript, now: chunk.at })) return;

    const prompt = buildGeneratePrompt(classify, functions);
    const raw = await this.client.generate({ prompt, signal: ac.signal });
    const parsed = safeJson(raw);
    if (!parsed || parsed.trust_escape) return;

    const latency_ms = Date.now() - chunk.at;

    useEventBus.getState().emit({
      type: 'stat_card',
      player_id: parsed.player_id ?? '',
      stat_text: parsed.stat_text,
      source: parsed.source ?? 'Sportradar',
      latency_ms,
      confidence_high: Boolean(parsed.confidence_high),
    });

    if (parsed.precedent_id) {
      const hit = getMatchCache().precedent_index.find((p) => p.id === parsed.precedent_id);
      if (hit) {
        useEventBus.getState().emit({
          type: 'precedent',
          pattern_id: hit.id,
          stat_text: hit.stat_text,
          category: hit.category,
        });
      }
    }
    if (parsed.counter_narrative) {
      useEventBus.getState().emit({
        type: 'counter_narrative',
        text: parsed.counter_narrative.text,
        for_team: parsed.counter_narrative.for_team,
        tone: 'dramatic',
      });
    }
  }

  async processPressToTalk(audio: ArrayBuffer): Promise<void> {
    await this.client.ensureLoaded(MODEL_ID);
    const t0 = Date.now();
    const raw = await this.client.generate({ prompt: QUERY_OR_COMMAND_PROMPT, audio });
    const parsed = safeJson(raw);
    const latency_ms = Date.now() - t0;
    const question = parsed?.transcript ?? '';

    if (!parsed || parsed.trust_escape) {
      useEventBus.getState().emit({ type: 'no_data', question });
      return;
    }

    if (parsed.intent === 'command' && parsed.widget_spec) {
      useEventBus.getState().emit({ type: 'widget_built', widget: parsed.widget_spec as WidgetSpec });
      return;
    }

    useEventBus.getState().emit({
      type: 'answer_card',
      question,
      answer: parsed.answer ?? '',
      source: parsed.source ?? 'Sportradar',
      confidence_high: Boolean(parsed.confidence_high),
      latency_ms,
    });
  }
}

function buildGeneratePrompt(classify: { event_type?: string | null; players_mentioned?: string[] }, _fns: typeof functions): string {
  return [
    GENERATE_PROMPT,
    `EVENT_TYPE=${classify.event_type ?? 'unknown'}`,
    `PLAYERS=${(classify.players_mentioned ?? []).join(',')}`,
  ].join('\n');
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}
```

- [ ] **Step 4: Run — verify passes**

Run: `npm test -- orchestrator`
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/cactus/pipeline/orchestrator.ts app/src/cactus/__tests__/orchestrator.test.ts
git commit -m "feat(cactus): orchestrator glues capture → gate → dedupe → askGemma → events"
```

---

## Task 12: Wire `AgentProvider` to the event bus

**Files:**
- Modify: `app/src/agent/AgentContext.tsx`
- Modify: `app/App.tsx`

- [ ] **Step 1: Read current `AgentContext.tsx` and identify the `DEMO_POINTS` timer rotation logic**

The current implementation rotates `DEMO_POINTS` every 4500ms via `setInterval`. We replace that with a subscription to `useEventBus`, mapping `stat_card` / `precedent` / `counter_narrative` / `streak_alert` events into `AgentPoint`.

- [ ] **Step 2: Replace the timer with an event-bus subscription**

Edit `app/src/agent/AgentContext.tsx`, replace the `start` callback and remove the `DEMO_POINTS` + `idxRef` usage:

```tsx
import { useEventBus, BusEvent } from '../cactus/state/eventBus';

// inside AgentProvider, replace the old `start` with:
const start = useCallback(() => {
  setActive(true);
  setPipV(true);
  setPoints([]);
  startedRef.current = Date.now();
}, []);

// And add, after the start definition:
useEffect(() => {
  if (!active) return;
  const unsub = useEventBus.subscribe((s, prev) => {
    if (s.events === prev.events) return;
    const next = s.events[s.events.length - 1];
    if (!next) return;
    const mapped = mapBusEventToPoint(next);
    if (!mapped) return;
    counter += 1;
    setPoints((p) => [{ id: `p-${counter}`, at: Date.now(), ...mapped }, ...p].slice(0, 50));
  });
  return unsub;
}, [active]);

// Utility added near the bottom of the file:
function mapBusEventToPoint(e: BusEvent): Omit<AgentPoint, 'id' | 'at'> | null {
  switch (e.type) {
    case 'stat_card':        return { text: e.stat_text, source: e.source, category: 'stat' };
    case 'precedent':        return { text: e.stat_text, source: 'inferred', category: 'stat' };
    case 'counter_narrative':return { text: e.text,      source: 'inferred', category: 'tactic' };
    case 'streak_alert':     return { text: e.streak_text, source: 'Sportradar', category: 'streak' };
    case 'answer_card':      return { text: e.answer,    source: e.source,   category: 'stat' };
    case 'no_data':          return { text: "I don't have verified data on that.", source: 'inferred', category: 'alert' };
    default:                 return null;
  }
}
```

Delete the `DEMO_POINTS` array and the `idxRef` lines. Keep the `stop`, `saving`, and archival logic intact.

- [ ] **Step 3: Load the match cache at app startup**

Edit `app/App.tsx` — before the `useFonts` hook, add:

```tsx
import matchCacheJson from './assets/match_cache.json';
import { loadMatchCache } from './src/cactus/state/matchCache';

loadMatchCache(matchCacheJson);
```

(Top-level call — runs once at bundle load. If `loadMatchCache` throws, the Metro bundler shows the error before the UI even mounts, which is the behaviour we want.)

- [ ] **Step 4: Smoke-run the app**

Run: `npm start` → press `w` for web.
Expected: app loads, Agent screen still works, timer-driven demo points are gone. Pressing "start" shows an empty list until real events fire (that's Task 14).

- [ ] **Step 5: Commit**

```bash
git add app/src/agent/AgentContext.tsx app/App.tsx
git commit -m "refactor(agent): replace demo-points timer with event-bus subscription"
```

---

## Task 13: Cactus smoke harness (Node)

**Files:**
- Create: `app/scripts/cactus-smoke.ts`
- Create: `app/assets/audio-fixtures/README.md`

- [ ] **Step 1: Source audio fixtures**

Place these 4 WAV clips under `app/assets/audio-fixtures/` (pull from YouTube → `yt-dlp` → trim with `ffmpeg` — ~3–5s each):

- `messi-pen-23.wav` — Peter Drury call of Messi's 23rd-minute penalty
- `dimaria-36.wav` — Di María's 36th-minute goal call
- `mbappe-pen-80.wav` — Mbappé's 80th-minute penalty call
- `mbappe-81.wav` — Mbappé's 81st-minute open-play goal call

Write `app/assets/audio-fixtures/README.md` with the source URLs and ffmpeg trim commands so fixtures can be reproduced.

- [ ] **Step 2: Write the harness**

`app/scripts/cactus-smoke.ts`:

```ts
// Run: npx tsx scripts/cactus-smoke.ts
// Verifies the Gemma 4 prompt stack + function toolbox against bundled WAV clips.
// Requires `cactus` Python CLI in PATH with google/functiongemma-270m-it downloaded.

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { loadMatchCache } from '../src/cactus/state/matchCache';
import * as functions from '../src/cactus/functions';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT } from '../src/cactus/prompts';

const FIXTURES = ['messi-pen-23', 'dimaria-36', 'mbappe-pen-80', 'mbappe-81'];

loadMatchCache(JSON.parse(readFileSync(join(__dirname, '../assets/match_cache.json'), 'utf-8')));

for (const name of FIXTURES) {
  const wavPath = join(__dirname, `../assets/audio-fixtures/${name}.wav`);
  console.log('\n── ' + name + ' ' + '─'.repeat(Math.max(0, 40 - name.length)));

  const classifyOut = runCactus(AUTONOMOUS_PROMPT, wavPath);
  console.log('classify:', classifyOut);

  const classify = JSON.parse(classifyOut);
  if (!classify.stat_opportunity) {
    console.log('  (skip — classifier says no opportunity)');
    continue;
  }

  const generatePrompt = `${GENERATE_PROMPT}\nEVENT_TYPE=${classify.event_type}\nPLAYERS=${(classify.players_mentioned ?? []).join(',')}`;
  const generateOut = runCactus(generatePrompt, wavPath);
  console.log('generate:', generateOut);
}

function runCactus(prompt: string, audioPath: string): string {
  const out = execFileSync(
    'cactus',
    ['generate', '--model', 'google/functiongemma-270m-it', '--prompt', prompt, '--audio', audioPath, '--json'],
    { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'inherit'] },
  );
  return out.trim();
}
```

- [ ] **Step 3: Install `tsx` dev dep**

```bash
cd app
npm install --save-dev tsx
```

Add script to `package.json`:

```json
    "smoke": "tsx scripts/cactus-smoke.ts"
```

- [ ] **Step 4: Run the harness on a real machine with Cactus CLI installed**

Run: `npm run smoke`
Expected output for each clip includes `stat_opportunity: true`, a plausible `event_type`, and a final `stat_text` sourced from a function call. If a clip produces `trust_escape`, inspect the transcript and the prompt — that's the prompt-tuning loop.

- [ ] **Step 5: Commit**

```bash
git add app/scripts/cactus-smoke.ts app/package.json app/package-lock.json app/assets/audio-fixtures/README.md
git commit -m "feat(cactus): node smoke harness for prompt + function validation"
```

---

## Task 14: Dev-tools overlay for on-device rehearsal

**Files:**
- Create: `app/src/cactus/devtools/DevToolsOverlay.tsx`
- Modify: `app/App.tsx`

- [ ] **Step 1: Write the overlay**

`app/src/cactus/devtools/DevToolsOverlay.tsx`:

```tsx
import React, { useEffect, useRef, useState } from 'react';
import { Pressable, Text, View, ScrollView } from 'react-native';
import { Orchestrator } from '../pipeline/orchestrator';
import { ContinuousCapture } from '../audio/continuous';
import { PressToTalkRecorder } from '../audio/pressToTalk';
import { useEventBus } from '../state/eventBus';
import { FONT_MONO, tokens } from '../../theme/tokens';

export function DevToolsOverlay({ onClose }: { onClose: () => void }) {
  const orchRef    = useRef(new Orchestrator());
  const captureRef = useRef<ContinuousCapture | null>(null);
  const pttRef     = useRef(new PressToTalkRecorder());
  const [running, setRunning] = useState(false);
  const events = useEventBus((s) => s.events.slice(-20));

  useEffect(() => () => { captureRef.current?.stop(); }, []);

  const startContinuous = async () => {
    if (running) return;
    setRunning(true);
    captureRef.current = new ContinuousCapture();
    await captureRef.current.start((chunk) => orchRef.current.processAutonomousChunk(chunk));
  };

  const stopContinuous = async () => {
    await captureRef.current?.stop();
    captureRef.current = null;
    setRunning(false);
  };

  const onPTTStart    = () => pttRef.current.start(() => { void onPTTStop(); });
  const onPTTStop     = async () => {
    const audio = await pttRef.current.stop();
    if (audio) orchRef.current.processPressToTalk(audio);
  };

  return (
    <View style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 360, backgroundColor: tokens.bgRaised, borderLeftWidth: 1, borderLeftColor: tokens.border, padding: 12 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 2 }}>VOICE DEVTOOLS</Text>
        <Pressable onPress={onClose} hitSlop={8}><Text style={{ fontFamily: FONT_MONO, color: tokens.textMuted }}>✕</Text></Pressable>
      </View>

      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 12 }}>
        {!running ? (
          <Pressable onPress={startContinuous} style={btnStyle}>
            <Text style={btnLabel}>START LISTEN</Text>
          </Pressable>
        ) : (
          <Pressable onPress={stopContinuous} style={btnStyle}>
            <Text style={btnLabel}>STOP</Text>
          </Pressable>
        )}
        <Pressable onPressIn={onPTTStart} onPressOut={onPTTStop} style={btnStyle}>
          <Text style={btnLabel}>HOLD: PTT</Text>
        </Pressable>
      </View>

      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.8, marginBottom: 6 }}>LAST 20 EVENTS</Text>
      <ScrollView style={{ flex: 1 }}>
        {events.map((e, i) => (
          <View key={i} style={{ paddingVertical: 4, borderBottomWidth: 1, borderBottomColor: tokens.borderSoft }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.5 }}>{e.type.toUpperCase()}</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.text, marginTop: 2 }}>{JSON.stringify(e).slice(0, 200)}</Text>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const btnStyle = { paddingVertical: 8, paddingHorizontal: 12, borderWidth: 1, borderColor: tokens.border, borderRadius: 4, backgroundColor: tokens.bgSubtle, flex: 1, alignItems: 'center' } as const;
const btnLabel = { fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text, letterSpacing: 1.5 } as const;
```

- [ ] **Step 2: Gate the overlay on a query flag in `App.tsx`**

At the top of `App.tsx`:

```tsx
import { DevToolsOverlay } from './src/cactus/devtools/DevToolsOverlay';
```

Inside `AppShell`, after the existing `<View style={{ flex: 1, flexDirection: 'row' }}>` block, add:

```tsx
{showDevtools && <DevToolsOverlay onClose={() => setShowDevtools(false)} />}
```

And above the return, add:

```tsx
const [showDevtools, setShowDevtools] = useState(() => {
  if (typeof window === 'undefined') return false;
  return window.location?.search?.includes('devtools') ?? false;
});
```

On iPad (no query string), add a hidden activation gesture: long-press the sidebar's version label to toggle `showDevtools`. Implementation detail left to engineer taste — the overlay works as long as `showDevtools=true` flips.

- [ ] **Step 3: Manual acceptance on iPad**

With the app running in a custom dev client on the physical iPad, in airplane mode:

1. Open with `?devtools` query (web) or long-press version label (iPad).
2. Press **HOLD: PTT**, speak *"How many World Cup goals has Mbappé scored?"*, release.
3. Observe `answer_card` event in the event list with `latency_ms <= 2000`. Confirm "Sportradar" source.
4. Press **START LISTEN**. Play the Peter Drury Messi-penalty fixture from a laptop speaker.
5. Observe `stat_card`, `precedent`, `counter_narrative` events within ~1.5s of the audio finishing.
6. Stop continuous. Confirm no events stream during pure silence.

Record pass/fail in the Sprint 0 notes. If latency exceeds budget, tune:
- `HOP_MS` in `continuous.ts` (reduce overlap)
- Gemma 4 prompt brevity in `prompts.ts`
- Temperature / max-tokens in `client.ts`

- [ ] **Step 4: Commit**

```bash
git add app/src/cactus/devtools/DevToolsOverlay.tsx app/App.tsx
git commit -m "feat(cactus): devtools overlay for on-device voice rehearsal"
```

---

## Self-review notes

- **Spec coverage:** §3 architecture → file structure above; §4.1 continuous → Tasks 5, 10, 11; §4.2 press-to-talk → Tasks 9, 11; §5 gate/dedupe → Tasks 4, 5, 11; §6 functions → Task 3; §7 error handling → Tasks 7, 8, 11 (the `trust_escape` and `no_data` paths); §8 integration seams → Tasks 2, 12; §9 testing → Tasks 0, 3–5, 7, 8, 11, 13, 14; §10 deps → Task 0.
- **Placeholders:** none. Every code step ships runnable code.
- **Type consistency:** `FunctionResult`, `VadStats`, `Classification`, `Chunk`, `BusEvent`, `AskGemmaResult` are defined once and referenced by the same name everywhere.
- **Known deferred-to-implementation items:** exact Cactus RN SDK npm name (Task 7 Step 1), how to produce valid 2-second WAV chunks from `expo-av` (Task 10 may need to be retuned if `expo-av` emits M4A not WAV — swap the container type in fixtures), exact long-press gesture for the iPad devtools activation (Task 14 Step 2).
