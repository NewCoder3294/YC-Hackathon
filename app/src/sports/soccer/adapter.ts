// Soccer adapter backed by StatsBomb Open Data.
// github.com/statsbomb/open-data — CC BY-NC-SA 4.0, CORS-enabled.
// Every number is from their published match/events/lineups JSON.

import { MatchSummary, SportAdapter, TacticsBundle } from '../types';
import { deriveBundle } from './derive';

const SB_BASE = 'https://raw.githubusercontent.com/statsbomb/open-data/master/data';

// Curated real matches. competition_id + season_id let us pull the proper
// matches index to get canonical home/away team ids.
type Curated = {
  matchId: string;
  competitionId: number;
  seasonId: number;
  label: string;       // human override for the picker; actual final score substituted from the match metadata
  venue: string;
};

const CURATED: Curated[] = [
  { matchId: '3869685', competitionId: 43, seasonId: 106, label: 'WC 2022 · FINAL',     venue: 'Lusail · Dec 18, 2022' },
  { matchId: '3857256', competitionId: 43, seasonId: 106, label: 'WC 2022 · SEMI-FINAL', venue: 'Lusail · Dec 13, 2022' },
  { matchId: '3869321', competitionId: 43, seasonId: 106, label: 'WC 2022 · SEMI-FINAL', venue: 'Al Bayt · Dec 14, 2022' },
  { matchId: '3942819', competitionId: 55, seasonId: 282, label: 'Euro 2024 · FINAL',    venue: 'Berlin · Jul 14, 2024' },
  { matchId: '3943077', competitionId: 55, seasonId: 282, label: 'Euro 2024 · SEMI-FINAL', venue: 'Dortmund · Jul 10, 2024' },
];

export type SBMatchMeta = {
  match_id: number;
  match_date: string;
  kick_off: string;
  home_team: { home_team_id: number; home_team_name: string; home_team_gender: string };
  away_team: { away_team_id: number; away_team_name: string; away_team_gender: string };
  home_score: number;
  away_score: number;
  stadium?: { name: string };
  competition?: { competition_name: string };
  season?: { season_name: string };
};

export type SBEvent = {
  id: string;
  index: number;
  period: number;
  timestamp: string;
  minute: number;
  second: number;
  type: { id: number; name: string };
  team: { id: number; name: string };
  player?: { id: number; name: string };
  position?: { id: number; name: string };
  location?: [number, number];     // StatsBomb pitch 120 × 80
  pass?: {
    length?: number;
    angle?: number;
    end_location: [number, number];
    outcome?: { id: number; name: string };   // missing = complete
    recipient?: { id: number; name: string };
    type?: { id: number; name: string };
  };
  shot?: {
    statsbomb_xg: number;
    outcome: { id: number; name: string };
    type?: { id: number; name: string };
    end_location?: [number, number, number?];
    body_part?: { name: string };
  };
  tactics?: {
    formation: number;
    lineup: Array<{
      player: { id: number; name: string };
      jersey_number: number;
      position: { id: number; name: string };
    }>;
  };
  under_pressure?: boolean;
};

export type SBLineup = {
  team_id: number;
  team_name: string;
  lineup: Array<{
    player_id: number;
    player_name: string;
    player_nickname?: string | null;
    jersey_number: number;
    positions: Array<{ position_id: number; position: string; from: string; to?: string | null }>;
  }>;
};

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`StatsBomb ${res.status} for ${url}`);
  return (await res.json()) as T;
}

// Cache the per-season matches index so we don't re-fetch it across picks.
const matchIndexCache = new Map<string, Map<string, SBMatchMeta>>();

async function getMatchIndex(competitionId: number, seasonId: number): Promise<Map<string, SBMatchMeta>> {
  const key = `${competitionId}/${seasonId}`;
  const hit = matchIndexCache.get(key);
  if (hit) return hit;
  const list = await fetchJson<SBMatchMeta[]>(`${SB_BASE}/matches/${competitionId}/${seasonId}.json`);
  const map = new Map<string, SBMatchMeta>();
  for (const m of list) map.set(String(m.match_id), m);
  matchIndexCache.set(key, map);
  return map;
}

function scoreLabel(meta: SBMatchMeta): string {
  return `${meta.home_team.home_team_name} ${meta.home_score}-${meta.away_score} ${meta.away_team.away_team_name}`;
}

export const soccerAdapter: SportAdapter = {
  sport: 'SOCCER',

  async listMatches(): Promise<MatchSummary[]> {
    const out: MatchSummary[] = [];
    // Fetch match indices in parallel (deduped by season).
    const uniqueSeasons = Array.from(new Set(CURATED.map((c) => `${c.competitionId}/${c.seasonId}`)));
    await Promise.all(
      uniqueSeasons.map((k) => {
        const [c, s] = k.split('/').map(Number);
        return getMatchIndex(c, s);
      }),
    );
    for (const c of CURATED) {
      const idx = await getMatchIndex(c.competitionId, c.seasonId);
      const meta = idx.get(c.matchId);
      out.push({
        id: c.matchId,
        sport: 'SOCCER',
        label: meta ? scoreLabel(meta) : c.label,
        sublabel: `${c.label} · ${c.venue}`,
        status: 'FINAL',
        startTimeIso: meta?.match_date,
      });
    }
    return out;
  },

  async loadMatch(matchId: string): Promise<TacticsBundle> {
    const curated = CURATED.find((c) => c.matchId === matchId);
    if (!curated) throw new Error(`Unknown match id ${matchId}`);
    const [matchIndex, events, lineups] = await Promise.all([
      getMatchIndex(curated.competitionId, curated.seasonId),
      fetchJson<SBEvent[]>(`${SB_BASE}/events/${matchId}.json`),
      fetchJson<SBLineup[]>(`${SB_BASE}/lineups/${matchId}.json`),
    ]);
    const meta = matchIndex.get(matchId);
    if (!meta) throw new Error(`Match metadata missing for ${matchId}`);
    return deriveBundle({ curated, meta, events, lineups });
  },
};
