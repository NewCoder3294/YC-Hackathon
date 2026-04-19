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

export function get_team_stat(team: 'arg' | 'fra' | 'home' | 'away', metric: string): FunctionResult {
  const cache = getMatchCache();
  const t = team === 'arg' || team === 'home' ? cache.teams.home : cache.teams.away;

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
