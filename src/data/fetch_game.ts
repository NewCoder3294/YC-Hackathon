#!/usr/bin/env ts-node
/**
 * fetch_game.ts — BroadcastBrain overnight game cache builder.
 *
 * WHAT THIS SCRIPT DOES:
 *   Run it the night before a game with a team name. It pulls everything the
 *   spotting board needs — next game details, both rosters, player stats,
 *   news headlines, and injury reports — then writes it all to
 *   assets/game_cache.json so the app works in airplane mode during the demo.
 *
 * HOW IT GETS THE DATA (no paid APIs, no API keys):
 *   Sport        │ API used
 *   ─────────────┼────────────────────────────────────────
 *   Soccer       │ ESPN unofficial (site.api.espn.com)
 *   Basketball   │ ESPN unofficial (site.api.espn.com)
 *   Baseball     │ MLB official   (statsapi.mlb.com)
 *   Hockey       │ NHL official   (api-web.nhle.com)
 *   News/injury  │ Google News RSS (news.google.com/rss)
 *
 * USAGE:
 *   npx ts-node src/data/fetch_game.ts "Manchester City"
 *   npx ts-node src/data/fetch_game.ts "Los Angeles Lakers"
 *   npx ts-node src/data/fetch_game.ts "New York Yankees"
 *   npx ts-node src/data/fetch_game.ts "Toronto Maple Leafs"
 *
 * OUTPUT:
 *   assets/game_cache.json
 */

import fetch from "node-fetch";
import * as fs from "fs";
import * as path from "path";

// ─────────────────────────────────────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────────────────────────────────────

interface PlayerStats {
  season: Record<string, string>;
  form_last_5: Record<string, string>;
  vs_opponent: Record<string, string>;
}

interface Player {
  id: string;
  team_id: string;
  shirt_number: number;
  name: string;
  position: string;
  age: number;
  stats: PlayerStats;
  storyline: string;
  matchup_note: string;
  top_stats: string[];
  status: "fit" | "doubtful" | "injured" | "suspended";
  news_headlines: string[];
}

interface Team {
  id: string;
  name: string;
  color_hex: string;
  record: Record<string, unknown>;
}

interface GameCache {
  match: {
    id: string;
    home_team: string;
    away_team: string;
    competition: string;
    venue: string;
    kickoff_iso: string;
  };
  teams: { home: Team; away: Team };
  players: Player[];
  storylines: string[];
  source: string;
  generated_at: string;
}

interface GameInfo {
  event_id: string;
  home_team: string;
  away_team: string;
  home_id: string;
  away_id: string;
  venue: string;
  date_iso: string;
  competition: string;
}

interface RawPlayer {
  id: string;
  name: string;
  number: number | null;
  position: string;
  age: number | null;
  headshot?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP HELPERS
// A small delay between every request keeps us from getting rate-limited.
// ─────────────────────────────────────────────────────────────────────────────

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
  "Accept-Language": "en-US,en;q=0.9",
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getJson<T = unknown>(url: string): Promise<T | null> {
  await sleep(500);
  try {
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) {
      console.error(`  [http] ${res.status} for ${url.slice(-80)}`);
      return null;
    }
    return (await res.json()) as T;
  } catch (e) {
    console.error(`  [http] failed: ${url.slice(-80)} → ${e}`);
    return null;
  }
}

async function getXml(url: string): Promise<string | null> {
  await sleep(500);
  try {
    const res = await fetch(url, { headers: HEADERS });
    if (!res.ok) return null;
    return await res.text();
  } catch (e) {
    console.error(`  [http] XML failed: ${url.slice(-80)} → ${e}`);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPORT DETECTION
//
// Checks a hardcoded lookup table first (instant for all major teams).
// Falls back to searching ESPN league endpoints if not found.
// Returns (sport, league, competitionDisplay) where sport matches ESPN's URL
// path (e.g. "basketball", "soccer") and league is the league slug (e.g. "nba").
// ─────────────────────────────────────────────────────────────────────────────

type SportEntry = [string, string, string]; // [sport, league, displayName]

const KNOWN_TEAMS: Record<string, SportEntry> = {
  // ── Soccer – Premier League ─────────────────────────────────────────────
  "manchester city":      ["soccer", "eng.1", "Premier League"],
  "manchester united":    ["soccer", "eng.1", "Premier League"],
  "liverpool":            ["soccer", "eng.1", "Premier League"],
  "arsenal":              ["soccer", "eng.1", "Premier League"],
  "chelsea":              ["soccer", "eng.1", "Premier League"],
  "tottenham":            ["soccer", "eng.1", "Premier League"],
  "spurs":                ["soccer", "eng.1", "Premier League"],
  "newcastle":            ["soccer", "eng.1", "Premier League"],
  "aston villa":          ["soccer", "eng.1", "Premier League"],
  "west ham":             ["soccer", "eng.1", "Premier League"],
  "brighton":             ["soccer", "eng.1", "Premier League"],
  "everton":              ["soccer", "eng.1", "Premier League"],
  "fulham":               ["soccer", "eng.1", "Premier League"],
  "brentford":            ["soccer", "eng.1", "Premier League"],
  "nottingham forest":    ["soccer", "eng.1", "Premier League"],
  "wolves":               ["soccer", "eng.1", "Premier League"],
  "wolverhampton":        ["soccer", "eng.1", "Premier League"],
  "crystal palace":       ["soccer", "eng.1", "Premier League"],
  "leicester":            ["soccer", "eng.1", "Premier League"],
  "ipswich":              ["soccer", "eng.1", "Premier League"],
  "southampton":          ["soccer", "eng.1", "Premier League"],
  "leeds":                ["soccer", "eng.1", "Premier League"],
  // ── Soccer – La Liga ────────────────────────────────────────────────────
  "real madrid":          ["soccer", "esp.1", "La Liga"],
  "barcelona":            ["soccer", "esp.1", "La Liga"],
  "atletico madrid":      ["soccer", "esp.1", "La Liga"],
  "athletic bilbao":      ["soccer", "esp.1", "La Liga"],
  "real sociedad":        ["soccer", "esp.1", "La Liga"],
  "villarreal":           ["soccer", "esp.1", "La Liga"],
  "sevilla":              ["soccer", "esp.1", "La Liga"],
  "betis":                ["soccer", "esp.1", "La Liga"],
  // ── Soccer – Bundesliga ─────────────────────────────────────────────────
  "bayern munich":        ["soccer", "ger.1", "Bundesliga"],
  "borussia dortmund":    ["soccer", "ger.1", "Bundesliga"],
  "bayer leverkusen":     ["soccer", "ger.1", "Bundesliga"],
  "rb leipzig":           ["soccer", "ger.1", "Bundesliga"],
  "eintracht frankfurt":  ["soccer", "ger.1", "Bundesliga"],
  // ── Soccer – Serie A ────────────────────────────────────────────────────
  "juventus":             ["soccer", "ita.1", "Serie A"],
  "inter milan":          ["soccer", "ita.1", "Serie A"],
  "ac milan":             ["soccer", "ita.1", "Serie A"],
  "napoli":               ["soccer", "ita.1", "Serie A"],
  "roma":                 ["soccer", "ita.1", "Serie A"],
  "lazio":                ["soccer", "ita.1", "Serie A"],
  "atalanta":             ["soccer", "ita.1", "Serie A"],
  "fiorentina":           ["soccer", "ita.1", "Serie A"],
  // ── Soccer – Ligue 1 ────────────────────────────────────────────────────
  "paris saint-germain":  ["soccer", "fra.1", "Ligue 1"],
  "psg":                  ["soccer", "fra.1", "Ligue 1"],
  "monaco":               ["soccer", "fra.1", "Ligue 1"],
  "marseille":            ["soccer", "fra.1", "Ligue 1"],
  "lyon":                 ["soccer", "fra.1", "Ligue 1"],
  "nice":                 ["soccer", "fra.1", "Ligue 1"],
  "lille":                ["soccer", "fra.1", "Ligue 1"],
  // ── Soccer – MLS ────────────────────────────────────────────────────────
  "inter miami":          ["soccer", "usa.1", "MLS"],
  "la galaxy":            ["soccer", "usa.1", "MLS"],
  "lafc":                 ["soccer", "usa.1", "MLS"],
  "seattle sounders":     ["soccer", "usa.1", "MLS"],
  "portland timbers":     ["soccer", "usa.1", "MLS"],
  "new york city":        ["soccer", "usa.1", "MLS"],
  "new york red bulls":   ["soccer", "usa.1", "MLS"],
  "atlanta united":       ["soccer", "usa.1", "MLS"],
  // ── NBA — ESPN sport string is "basketball" ──────────────────────────────
  "los angeles lakers":   ["basketball", "nba", "NBA"],
  "lakers":               ["basketball", "nba", "NBA"],
  "golden state warriors":["basketball", "nba", "NBA"],
  "warriors":             ["basketball", "nba", "NBA"],
  "boston celtics":       ["basketball", "nba", "NBA"],
  "celtics":              ["basketball", "nba", "NBA"],
  "miami heat":           ["basketball", "nba", "NBA"],
  "chicago bulls":        ["basketball", "nba", "NBA"],
  "brooklyn nets":        ["basketball", "nba", "NBA"],
  "new york knicks":      ["basketball", "nba", "NBA"],
  "knicks":               ["basketball", "nba", "NBA"],
  "dallas mavericks":     ["basketball", "nba", "NBA"],
  "mavs":                 ["basketball", "nba", "NBA"],
  "milwaukee bucks":      ["basketball", "nba", "NBA"],
  "denver nuggets":       ["basketball", "nba", "NBA"],
  "phoenix suns":         ["basketball", "nba", "NBA"],
  "philadelphia 76ers":   ["basketball", "nba", "NBA"],
  "cleveland cavaliers":  ["basketball", "nba", "NBA"],
  "oklahoma city thunder":["basketball", "nba", "NBA"],
  "houston rockets":      ["basketball", "nba", "NBA"],
  "memphis grizzlies":    ["basketball", "nba", "NBA"],
  "sacramento kings":     ["basketball", "nba", "NBA"],
  "minnesota timberwolves":["basketball","nba", "NBA"],
  "indiana pacers":       ["basketball", "nba", "NBA"],
  "new orleans pelicans": ["basketball", "nba", "NBA"],
  "toronto raptors":      ["basketball", "nba", "NBA"],
  "atlanta hawks":        ["basketball", "nba", "NBA"],
  "orlando magic":        ["basketball", "nba", "NBA"],
  "washington wizards":   ["basketball", "nba", "NBA"],
  "detroit pistons":      ["basketball", "nba", "NBA"],
  "charlotte hornets":    ["basketball", "nba", "NBA"],
  "portland trail blazers":["basketball","nba", "NBA"],
  "san antonio spurs":    ["basketball", "nba", "NBA"],
  "utah jazz":            ["basketball", "nba", "NBA"],
  // ── MLB — uses official MLB API (statsapi.mlb.com) ──────────────────────
  "new york yankees":     ["baseball", "mlb", "MLB"],
  "yankees":              ["baseball", "mlb", "MLB"],
  "los angeles dodgers":  ["baseball", "mlb", "MLB"],
  "dodgers":              ["baseball", "mlb", "MLB"],
  "boston red sox":       ["baseball", "mlb", "MLB"],
  "red sox":              ["baseball", "mlb", "MLB"],
  "chicago cubs":         ["baseball", "mlb", "MLB"],
  "san francisco giants": ["baseball", "mlb", "MLB"],
  "new york mets":        ["baseball", "mlb", "MLB"],
  "mets":                 ["baseball", "mlb", "MLB"],
  "houston astros":       ["baseball", "mlb", "MLB"],
  "astros":               ["baseball", "mlb", "MLB"],
  "atlanta braves":       ["baseball", "mlb", "MLB"],
  "braves":               ["baseball", "mlb", "MLB"],
  "philadelphia phillies":["baseball", "mlb", "MLB"],
  "phillies":             ["baseball", "mlb", "MLB"],
  "st. louis cardinals":  ["baseball", "mlb", "MLB"],
  "cardinals":            ["baseball", "mlb", "MLB"],
  "seattle mariners":     ["baseball", "mlb", "MLB"],
  "mariners":             ["baseball", "mlb", "MLB"],
  "chicago white sox":    ["baseball", "mlb", "MLB"],
  "minnesota twins":      ["baseball", "mlb", "MLB"],
  "cleveland guardians":  ["baseball", "mlb", "MLB"],
  "miami marlins":        ["baseball", "mlb", "MLB"],
  "tampa bay rays":       ["baseball", "mlb", "MLB"],
  "toronto blue jays":    ["baseball", "mlb", "MLB"],
  "blue jays":            ["baseball", "mlb", "MLB"],
  "baltimore orioles":    ["baseball", "mlb", "MLB"],
  "orioles":              ["baseball", "mlb", "MLB"],
  "texas rangers":        ["baseball", "mlb", "MLB"],
  "kansas city royals":   ["baseball", "mlb", "MLB"],
  "royals":               ["baseball", "mlb", "MLB"],
  "oakland athletics":    ["baseball", "mlb", "MLB"],
  "athletics":            ["baseball", "mlb", "MLB"],
  "colorado rockies":     ["baseball", "mlb", "MLB"],
  "rockies":              ["baseball", "mlb", "MLB"],
  "san diego padres":     ["baseball", "mlb", "MLB"],
  "padres":               ["baseball", "mlb", "MLB"],
  "cincinnati reds":      ["baseball", "mlb", "MLB"],
  "pittsburgh pirates":   ["baseball", "mlb", "MLB"],
  "detroit tigers":       ["baseball", "mlb", "MLB"],
  "tigers":               ["baseball", "mlb", "MLB"],
  "arizona diamondbacks": ["baseball", "mlb", "MLB"],
  "milwaukee brewers":    ["baseball", "mlb", "MLB"],
  "brewers":              ["baseball", "mlb", "MLB"],
  "washington nationals": ["baseball", "mlb", "MLB"],
  "los angeles angels":   ["baseball", "mlb", "MLB"],
  "angels":               ["baseball", "mlb", "MLB"],
  // ── NHL — uses official NHL API (api-web.nhle.com) ──────────────────────
  "toronto maple leafs":  ["hockey", "nhl", "NHL"],
  "leafs":                ["hockey", "nhl", "NHL"],
  "montreal canadiens":   ["hockey", "nhl", "NHL"],
  "canadiens":            ["hockey", "nhl", "NHL"],
  "boston bruins":        ["hockey", "nhl", "NHL"],
  "bruins":               ["hockey", "nhl", "NHL"],
  "new york rangers":     ["hockey", "nhl", "NHL"],
  "edmonton oilers":      ["hockey", "nhl", "NHL"],
  "oilers":               ["hockey", "nhl", "NHL"],
  "colorado avalanche":   ["hockey", "nhl", "NHL"],
  "avalanche":            ["hockey", "nhl", "NHL"],
  "tampa bay lightning":  ["hockey", "nhl", "NHL"],
  "lightning":            ["hockey", "nhl", "NHL"],
  "vegas golden knights": ["hockey", "nhl", "NHL"],
  "golden knights":       ["hockey", "nhl", "NHL"],
  "carolina hurricanes":  ["hockey", "nhl", "NHL"],
  "hurricanes":           ["hockey", "nhl", "NHL"],
  "florida panthers":     ["hockey", "nhl", "NHL"],
  "panthers":             ["hockey", "nhl", "NHL"],
  "dallas stars":         ["hockey", "nhl", "NHL"],
  "stars":                ["hockey", "nhl", "NHL"],
  "new york islanders":   ["hockey", "nhl", "NHL"],
  "islanders":            ["hockey", "nhl", "NHL"],
  "new jersey devils":    ["hockey", "nhl", "NHL"],
  "devils":               ["hockey", "nhl", "NHL"],
  "pittsburgh penguins":  ["hockey", "nhl", "NHL"],
  "penguins":             ["hockey", "nhl", "NHL"],
  "detroit red wings":    ["hockey", "nhl", "NHL"],
  "red wings":            ["hockey", "nhl", "NHL"],
  "nashville predators":  ["hockey", "nhl", "NHL"],
  "predators":            ["hockey", "nhl", "NHL"],
  "minnesota wild":       ["hockey", "nhl", "NHL"],
  "wild":                 ["hockey", "nhl", "NHL"],
  "winnipeg jets":        ["hockey", "nhl", "NHL"],
  "jets":                 ["hockey", "nhl", "NHL"],
  "st. louis blues":      ["hockey", "nhl", "NHL"],
  "blues":                ["hockey", "nhl", "NHL"],
  "seattle kraken":       ["hockey", "nhl", "NHL"],
  "kraken":               ["hockey", "nhl", "NHL"],
  "chicago blackhawks":   ["hockey", "nhl", "NHL"],
  "blackhawks":           ["hockey", "nhl", "NHL"],
  "ottawa senators":      ["hockey", "nhl", "NHL"],
  "senators":             ["hockey", "nhl", "NHL"],
  "calgary flames":       ["hockey", "nhl", "NHL"],
  "flames":               ["hockey", "nhl", "NHL"],
  "vancouver canucks":    ["hockey", "nhl", "NHL"],
  "canucks":              ["hockey", "nhl", "NHL"],
  "buffalo sabres":       ["hockey", "nhl", "NHL"],
  "sabres":               ["hockey", "nhl", "NHL"],
  "san jose sharks":      ["hockey", "nhl", "NHL"],
  "sharks":               ["hockey", "nhl", "NHL"],
  "philadelphia flyers":  ["hockey", "nhl", "NHL"],
  "flyers":               ["hockey", "nhl", "NHL"],
  "anaheim ducks":        ["hockey", "nhl", "NHL"],
  "ducks":                ["hockey", "nhl", "NHL"],
  "columbus blue jackets":["hockey", "nhl", "NHL"],
  "washington capitals":  ["hockey", "nhl", "NHL"],
  "capitals":             ["hockey", "nhl", "NHL"],
};

// ESPN league endpoints to search through when team isn't in KNOWN_TEAMS
const ESPN_LEAGUES: Array<[string, string]> = [
  ["soccer", "eng.1"],
  ["soccer", "esp.1"],
  ["soccer", "ger.1"],
  ["soccer", "ita.1"],
  ["soccer", "fra.1"],
  ["soccer", "usa.1"],
  ["basketball", "nba"],
];

const TEAM_COLORS: Record<string, string> = {
  "manchester city": "#6CABDD", "manchester united": "#DA291C",
  "liverpool": "#C8102E", "arsenal": "#EF0107", "chelsea": "#034694",
  "tottenham": "#132257", "newcastle": "#241F20", "aston villa": "#95BFE5",
  "real madrid": "#FEBE10", "barcelona": "#A50044", "atletico madrid": "#CB3524",
  "juventus": "#000000", "inter milan": "#010E80", "ac milan": "#FB090B",
  "napoli": "#087AC6", "paris saint-germain": "#004170",
  "bayern munich": "#DC052D", "borussia dortmund": "#FDE100",
  "los angeles lakers": "#552583", "golden state warriors": "#1D428A",
  "boston celtics": "#007A33", "chicago bulls": "#CE1141",
  "miami heat": "#98002E", "brooklyn nets": "#000000",
  "new york yankees": "#003087", "los angeles dodgers": "#005A9C",
  "boston red sox": "#BD3039", "chicago cubs": "#0E3386",
  "houston astros": "#002D62", "atlanta braves": "#CE1141",
  "toronto maple leafs": "#003E7E", "montreal canadiens": "#AF1E2D",
  "boston bruins": "#FFB81C", "edmonton oilers": "#FF4C00",
  "colorado avalanche": "#6F263D", "tampa bay lightning": "#002868",
  "default": "#1A1A2E",
};

// NHL 3-letter abbreviations (required by the NHL API URL format)
const NHL_ABBREVS: Record<string, string> = {
  "toronto": "TOR", "maple leafs": "TOR", "leafs": "TOR",
  "montreal": "MTL", "canadiens": "MTL",
  "boston": "BOS", "bruins": "BOS",
  "new york rangers": "NYR", "rangers": "NYR",
  "new york islanders": "NYI", "islanders": "NYI",
  "new jersey": "NJD", "devils": "NJD",
  "philadelphia": "PHI", "flyers": "PHI",
  "pittsburgh": "PIT", "penguins": "PIT",
  "buffalo": "BUF", "sabres": "BUF",
  "detroit": "DET", "red wings": "DET",
  "ottawa": "OTT", "senators": "OTT",
  "carolina": "CAR", "hurricanes": "CAR",
  "washington": "WSH", "capitals": "WSH",
  "columbus": "CBJ", "blue jackets": "CBJ",
  "florida": "FLA", "panthers": "FLA",
  "tampa bay": "TBL", "lightning": "TBL",
  "nashville": "NSH", "predators": "NSH",
  "chicago": "CHI", "blackhawks": "CHI",
  "st. louis": "STL", "blues": "STL",
  "minnesota": "MIN", "wild": "MIN",
  "winnipeg": "WPG", "jets": "WPG",
  "dallas": "DAL", "stars": "DAL",
  "colorado": "COL", "avalanche": "COL",
  "edmonton": "EDM", "oilers": "EDM",
  "calgary": "CGY", "flames": "CGY",
  "vancouver": "VAN", "canucks": "VAN",
  "seattle": "SEA", "kraken": "SEA",
  "vegas": "VGK", "golden knights": "VGK",
  "utah": "UTA", "arizona": "UTA",
  "san jose": "SJS", "sharks": "SJS",
  "anaheim": "ANA", "ducks": "ANA",
  "los angeles": "LAK", "kings": "LAK",
};

// ─────────────────────────────────────────────────────────────────────────────
// SPORT DETECTION
// ─────────────────────────────────────────────────────────────────────────────

async function detectSport(teamName: string): Promise<SportEntry> {
  const lower = teamName.toLowerCase().trim();

  // Step 1: direct lookup — covers 95% of cases instantly
  for (const [key, value] of Object.entries(KNOWN_TEAMS)) {
    if (key.includes(lower) || lower.includes(key)) {
      console.error(`  [detect] matched known team: '${key}' → ${value[2]}`);
      return value;
    }
  }

  // Step 2: search ESPN league endpoints
  console.error("  [detect] not in known list, searching ESPN leagues...");
  for (const [sport, league] of ESPN_LEAGUES) {
    const data = await getJson<any>(
      `https://site.api.espn.com/apis/site/v2/sports/${sport}/${league}/teams`
    );
    if (!data) continue;
    const teams: any[] =
      data?.sports?.[0]?.leagues?.[0]?.teams ?? [];
    for (const entry of teams) {
      const t = entry.team ?? {};
      const name: string = (t.displayName ?? "").toLowerCase();
      const nickname: string = (t.nickname ?? "").toLowerCase();
      if (lower.includes(name) || name.includes(lower) || nickname.includes(lower)) {
        console.error(`  [detect] ESPN match: ${t.displayName} in ${league}`);
        return [sport, league, league.toUpperCase()];
      }
    }
  }

  console.error("  [detect] could not detect sport, defaulting to PL soccer");
  return ["soccer", "eng.1", "Premier League"];
}

// ─────────────────────────────────────────────────────────────────────────────
// ESPN FUNCTIONS  (soccer + basketball)
// ─────────────────────────────────────────────────────────────────────────────

const ESPN_BASE = "https://site.api.espn.com/apis/site/v2/sports";
const ESPN_CORE = "https://sports.core.api.espn.com/v2/sports";

async function espnFindTeamId(
  teamName: string, sport: string, league: string
): Promise<string | null> {
  const data = await getJson<any>(
    `${ESPN_BASE}/${sport}/${league}/teams`
  );
  if (!data) return null;

  const teams: any[] = data?.sports?.[0]?.leagues?.[0]?.teams ?? [];
  const lower = teamName.toLowerCase();
  let bestId: string | null = null;
  let bestScore = 0;

  for (const entry of teams) {
    const t = entry.team ?? {};
    const name: string = (t.displayName ?? "").toLowerCase();
    const nickname: string = (t.nickname ?? "").toLowerCase();
    const slug: string = (t.slug ?? "").toLowerCase();

    let score = 0;
    if (lower === name) score = 100;
    else if (lower.includes(name) || name.includes(lower)) score = 80;
    else if (nickname.includes(lower) || lower.includes(nickname)) score = 60;
    else if (slug.includes(lower)) score = 50;
    else if (lower.split(" ").some((w) => w.length > 3 && name.includes(w))) score = 30;

    if (score > bestScore) {
      bestScore = score;
      bestId = t.id;
    }
  }

  console.error(`  [espn] team ID = ${bestId} (score=${bestScore})`);
  return bestId;
}

async function espnNextGame(
  teamId: string, sport: string, league: string
): Promise<GameInfo | null> {
  const data = await getJson<any>(
    `${ESPN_BASE}/${sport}/${league}/teams/${teamId}/schedule`
  );
  if (!data) return null;

  for (const event of data.events ?? []) {
    const comp = event.competitions?.[0];
    if (!comp) continue;
    const state: string = comp.status?.type?.state ?? "";
    if (state !== "pre") continue;

    const competitors: any[] = comp.competitors ?? [];
    const home = competitors.find((c: any) => c.homeAway === "home") ?? {};
    const away = competitors.find((c: any) => c.homeAway === "away") ?? {};

    return {
      event_id:    event.id ?? "",
      home_team:   home.team?.displayName ?? "",
      away_team:   away.team?.displayName ?? "",
      home_id:     home.team?.id ?? "",
      away_id:     away.team?.id ?? "",
      venue:       comp.venue?.fullName ?? "TBD",
      date_iso:    event.date ?? "",
      competition: data.season?.displayName ?? "",
    };
  }
  return null;
}

async function espnRoster(
  teamId: string, sport: string, league: string
): Promise<RawPlayer[]> {
  const data = await getJson<any>(
    `${ESPN_BASE}/${sport}/${league}/teams/${teamId}/roster`
  );
  if (!data) return [];

  const players: RawPlayer[] = [];
  for (const item of data.athletes ?? []) {
    if (item.items) {
      for (const p of item.items) players.push(parseEspnAthlete(p));
    } else {
      players.push(parseEspnAthlete(item));
    }
  }

  console.error(`  [espn] roster: ${players.length} players`);
  return players;
}

function parseEspnAthlete(a: any): RawPlayer {
  return {
    id:       a.id ?? "",
    name:     a.displayName ?? a.fullName ?? "",
    number:   parseInt(a.jersey ?? "") || null,
    position: a.position?.abbreviation ?? "",
    age:      a.age ?? null,
    headshot: a.headshot?.href ?? "",
  };
}

async function espnPlayerStats(
  playerId: string, sport: string, league: string
): Promise<Record<string, string>> {
  const data = await getJson<any>(
    `${ESPN_CORE}/${sport}/leagues/${league}/athletes/${playerId}/statistics/0`
  );
  if (!data) return {};

  const stats: Record<string, string> = {};
  for (const cat of data.splits?.categories ?? []) {
    for (const stat of cat.stats ?? []) {
      const name: string = stat.displayName ?? "";
      const value: string = stat.displayValue ?? "—";
      if (name && !["", "0", "0.0"].includes(value)) {
        stats[name] = value;
      }
    }
  }
  return stats;
}

async function espnTeamNews(
  teamId: string, sport: string, league: string
): Promise<string[]> {
  const data = await getJson<any>(
    `${ESPN_BASE}/${sport}/${league}/news?team=${teamId}&limit=10`
  );
  if (!data) return [];
  return (data.articles ?? [])
    .map((a: any) => a.headline?.trim() ?? "")
    .filter(Boolean)
    .slice(0, 6);
}

// ─────────────────────────────────────────────────────────────────────────────
// MLB FUNCTIONS  (official MLB Stats API — statsapi.mlb.com)
// ─────────────────────────────────────────────────────────────────────────────

const MLB_BASE = "https://statsapi.mlb.com/api/v1";

async function mlbFindTeamId(teamName: string): Promise<string | null> {
  const data = await getJson<any>(`${MLB_BASE}/teams?sportId=1`);
  if (!data) return null;

  const lower = teamName.toLowerCase();
  for (const team of data.teams ?? []) {
    const name: string = (team.name ?? "").toLowerCase();
    const short: string = (team.teamName ?? "").toLowerCase();
    if (lower.includes(name) || name.includes(lower) || lower.includes(short)) {
      console.error(`  [mlb] team ID = ${team.id} (${team.name})`);
      return String(team.id);
    }
  }
  return null;
}

async function mlbNextGame(teamId: string): Promise<GameInfo | null> {
  const data = await getJson<any>(
    `${MLB_BASE}/schedule/games/?sportId=1&teamId=${teamId}`
  );
  if (!data) return null;

  const dates: any[] = data.dates ?? [];
  if (!dates.length) return null;

  const game = dates[0].games[0];
  return {
    event_id:    String(game.gamePk ?? ""),
    home_team:   game.teams.home.team.name,
    away_team:   game.teams.away.team.name,
    home_id:     String(game.teams.home.team.id),
    away_id:     String(game.teams.away.team.id),
    venue:       game.venue?.name ?? "TBD",
    date_iso:    game.gameDate ?? "",
    competition: "MLB",
  };
}

async function mlbRoster(teamId: string): Promise<RawPlayer[]> {
  const data = await getJson<any>(
    `${MLB_BASE}/teams/${teamId}/roster?season=2026&rosterType=active`
  );
  if (!data) return [];

  const players: RawPlayer[] = (data.roster ?? []).map((entry: any) => ({
    id:       String(entry.person.id),
    name:     entry.person.fullName,
    number:   parseInt(entry.jerseyNumber ?? "") || null,
    position: entry.position?.abbreviation ?? "",
    age:      null,
  }));

  console.error(`  [mlb] roster: ${players.length} players`);
  return players;
}

async function mlbPlayerStats(playerId: string): Promise<Record<string, string>> {
  for (const group of ["hitting", "pitching"]) {
    const data = await getJson<any>(
      `${MLB_BASE}/people/${playerId}/stats?stats=season&season=2026&group=${group}`
    );
    if (!data) continue;
    const splits: any[] = data.stats?.[0]?.splits ?? [];
    if (!splits.length) continue;

    const stat = splits[0].stat ?? {};
    const result: Record<string, string> = {};
    for (const [k, v] of Object.entries(stat)) {
      if (v !== null && v !== undefined && !["0", "0.0", ".000", "", 0].includes(v as any)) {
        result[k] = String(v);
      }
    }
    if (Object.keys(result).length) return result;
  }
  return {};
}

// ─────────────────────────────────────────────────────────────────────────────
// NHL FUNCTIONS  (official NHL API — api-web.nhle.com)
// ─────────────────────────────────────────────────────────────────────────────

const NHL_BASE = "https://api-web.nhle.com/v1";

function nhlAbbrev(teamName: string): string | null {
  const lower = teamName.toLowerCase();
  for (const [key, abbrev] of Object.entries(NHL_ABBREVS)) {
    if (lower.includes(key)) return abbrev;
  }
  return null;
}

async function nhlNextGame(abbrev: string): Promise<GameInfo | null> {
  const data = await getJson<any>(
    `${NHL_BASE}/club-schedule-season/${abbrev}/now`
  );
  if (!data) return null;

  for (const game of data.games ?? []) {
    if (!["FUT", "PRE"].includes(game.gameState)) continue;
    const home = game.homeTeam ?? {};
    const away = game.awayTeam ?? {};
    return {
      event_id:    String(game.id ?? ""),
      home_team:   `${home.placeName?.default ?? ""} ${home.commonName?.default ?? ""}`.trim(),
      away_team:   `${away.placeName?.default ?? ""} ${away.commonName?.default ?? ""}`.trim(),
      home_id:     home.abbrev ?? "",
      away_id:     away.abbrev ?? "",
      venue:       game.venue?.default ?? "TBD",
      date_iso:    game.gameDate ?? "",
      competition: "NHL",
    };
  }
  return null;
}

async function nhlRoster(abbrev: string): Promise<RawPlayer[]> {
  const data = await getJson<any>(`${NHL_BASE}/roster/${abbrev}/current`);
  if (!data) return [];

  const players: RawPlayer[] = [];
  for (const group of ["forwards", "defensemen", "goalies"] as const) {
    for (const p of data[group] ?? []) {
      const birthDate: string = p.birthDate ?? "";
      players.push({
        id:       String(p.id ?? ""),
        name:     `${p.firstName?.default ?? ""} ${p.lastName?.default ?? ""}`.trim(),
        number:   p.sweaterNumber ?? null,
        position: p.positionCode ?? "",
        age:      birthDate ? calcAge(birthDate) : null,
        headshot: p.headshot ?? "",
      });
    }
  }

  console.error(`  [nhl] roster: ${players.length} players`);
  return players;
}

async function nhlPlayerStats(playerId: string): Promise<Record<string, string>> {
  const data = await getJson<any>(`${NHL_BASE}/player/${playerId}/landing`);
  if (!data) return {};

  const totals: any[] = data.seasonTotals ?? [];
  if (!totals.length) return {};

  const latest = totals[totals.length - 1];
  const keys = ["goals","assists","points","plusMinus","pim","shots",
                 "gamesPlayed","savePctg","goalsAgainstAvg","shutouts","wins"];
  const stats: Record<string, string> = {};
  for (const key of keys) {
    const val = latest[key];
    if (val !== undefined && val !== null && val !== 0) {
      stats[key] = String(val);
    }
  }
  return stats;
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE NEWS RSS  (news + injuries for all sports)
//
// Google News provides a free RSS feed — no API key needed.
// Each <item> has a <title> we parse with a simple regex.
// ─────────────────────────────────────────────────────────────────────────────

async function googleNews(query: string, maxResults = 5): Promise<string[]> {
  const url = `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=en-US&gl=US&ceid=US:en`;
  const xml = await getXml(url);
  if (!xml) return [];

  const headlines: string[] = [];
  const matches = xml.matchAll(/<title><!\[CDATA\[(.*?)\]\]><\/title>|<title>(.*?)<\/title>/g);
  for (const m of matches) {
    const raw = (m[1] ?? m[2] ?? "").trim();
    if (!raw || raw === "Google News") continue;
    // Strip trailing " - Source Name"
    const clean = raw.replace(/\s*-\s*[^-]+$/, "").trim();
    if (clean) headlines.push(clean);
    if (headlines.length >= maxResults) break;
  }
  return headlines;
}

async function fetchNewsForTeam(teamName: string): Promise<string[]> {
  return googleNews(`${teamName} news 2026`, 6);
}

async function fetchNewsForPlayer(playerName: string, teamName: string): Promise<string[]> {
  return googleNews(`${playerName} ${teamName} 2026`, 3);
}

async function fetchInjuryReport(teamName: string): Promise<string[]> {
  return googleNews(`${teamName} injury suspended doubtful out 2026`, 8);
}

// ─────────────────────────────────────────────────────────────────────────────
// STORYLINE GENERATOR
// ─────────────────────────────────────────────────────────────────────────────

function makeStoryline(
  name: string, position: string,
  stats: Record<string, string>, news: string[], status: string
): string {
  if (["injured", "doubtful", "suspended"].includes(status)) {
    return `${name} is listed as ${status} — his availability is the key team news heading in.`;
  }
  if (news.length) {
    const headline = news[0].replace(/\s*-\s*[^-]+$/, "").trim();
    if (headline.length > 10) return headline;
  }
  const entries = Object.entries(stats);
  if (entries.length) {
    const [key, val] = entries[0];
    return `${name} brings ${val} ${key} into this matchup — one of the key figures to watch.`;
  }
  return `${name} is a key ${position} piece in this lineup — watch how they influence the game.`;
}

function makeMatchupNote(name: string, opponent: string): string {
  return `${name} faces ${opponent} — a key individual battle to monitor throughout.`;
}

function inferStatus(
  playerName: string, injuryHeadlines: string[]
): "fit" | "doubtful" | "injured" | "suspended" {
  const parts = playerName.toLowerCase().split(" ").filter((p) => p.length > 2);
  for (const headline of injuryHeadlines) {
    const hl = headline.toLowerCase();
    if (!parts.some((p) => hl.includes(p))) continue;
    if (hl.includes("suspend")) return "suspended";
    if (hl.includes("doubtful")) return "doubtful";
    if (["out", "ruled out", "injured", "sidelined", "misses"].some((w) => hl.includes(w))) {
      return "injured";
    }
  }
  return "fit";
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITY HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function calcAge(birthDate: string): number | null {
  try {
    const bd = new Date(birthDate);
    const today = new Date();
    let age = today.getFullYear() - bd.getFullYear();
    const m = today.getMonth() - bd.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < bd.getDate())) age--;
    return age;
  } catch {
    return null;
  }
}

function teamColor(teamName: string): string {
  const lower = teamName.toLowerCase();
  for (const [key, color] of Object.entries(TEAM_COLORS)) {
    if (lower.includes(key)) return color;
  }
  return TEAM_COLORS["default"];
}

function makeId(...parts: string[]): string {
  const raw = parts.filter(Boolean).join("-").toLowerCase().trim();
  return raw.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "unknown";
}

function topStats(stats: Record<string, string>, limit = 3): string[] {
  return Object.entries(stats)
    .filter(([, v]) => v && !["—", "", "0", "0.0", "None"].includes(v))
    .slice(0, limit)
    .map(([k, v]) => `${v} ${k}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ORCHESTRATOR
// ─────────────────────────────────────────────────────────────────────────────

async function buildGameCache(teamName: string): Promise<GameCache> {
  console.error(`\n${"=".repeat(50)}`);
  console.error(`BroadcastBrain Cache Builder — ${teamName}`);
  console.error(`${"=".repeat(50)}\n`);

  // ── 1. DETECT SPORT ────────────────────────────────────────────────────────
  console.error("[1/5] Detecting sport...");
  const [sport, league, competitionDisplay] = await detectSport(teamName);
  console.error(`      → ${competitionDisplay}\n`);

  // ── 2. FIND NEXT GAME ──────────────────────────────────────────────────────
  console.error("[2/5] Finding next game...");
  let gameInfo: GameInfo | null = null;
  let ourTeamId = "";

  if (sport === "soccer" || sport === "basketball") {
    ourTeamId = (await espnFindTeamId(teamName, sport, league)) ?? "";
    if (ourTeamId) gameInfo = await espnNextGame(ourTeamId, sport, league);
  } else if (sport === "baseball") {
    ourTeamId = (await mlbFindTeamId(teamName)) ?? "";
    if (ourTeamId) gameInfo = await mlbNextGame(ourTeamId);
  } else if (sport === "hockey") {
    ourTeamId = nhlAbbrev(teamName) ?? "";
    if (ourTeamId) gameInfo = await nhlNextGame(ourTeamId);
  }

  // Fallback: try Google News to find the opponent
  if (!gameInfo) {
    console.error("      → No upcoming game in API, trying Google News...");
    const newsHints = await googleNews(`${teamName} next match fixture 2026`, 8);
    let opponentHint = "";

    for (const headline of newsHints) {
      const hl = headline.toLowerCase();
      const teamWords = teamName.toLowerCase().split(" ").filter((w) => w.length > 3);
      if (!teamWords.some((w) => hl.includes(w))) continue;
      for (const [known] of Object.entries(KNOWN_TEAMS)) {
        if (hl.includes(known) && !teamName.toLowerCase().includes(known)) {
          if (known.length > opponentHint.length) opponentHint = known;
        }
      }
      if (opponentHint) {
        opponentHint = opponentHint.replace(/\b\w/g, (c) => c.toUpperCase());
        console.error(`      → Extracted opponent from news: '${opponentHint}'`);
        break;
      }
    }

    gameInfo = {
      event_id:    "tbd",
      home_team:   teamName,
      away_team:   opponentHint || "TBD",
      home_id:     ourTeamId,
      away_id:     "",
      venue:       "TBD",
      date_iso:    new Date().toISOString(),
      competition: competitionDisplay,
    };
  }

  const homeTeam = gameInfo.home_team;
  const awayTeam = gameInfo.away_team;
  console.error(`      → ${homeTeam} vs ${awayTeam} at ${gameInfo.venue}\n`);

  // ── 3. FETCH BOTH ROSTERS ──────────────────────────────────────────────────
  console.error("[3/5] Fetching rosters...");
  let homePlayersRaw: RawPlayer[] = [];
  let awayPlayersRaw: RawPlayer[] = [];

  const isHome = teamName.toLowerCase().includes(homeTeam.toLowerCase()) ||
                 homeTeam.toLowerCase().includes(teamName.toLowerCase());
  const oppName = isHome ? awayTeam : homeTeam;
  let oppApiId = isHome ? gameInfo.away_id : gameInfo.home_id;

  if (sport === "soccer" || sport === "basketball") {
    if (ourTeamId) {
      console.error(`      → Fetching ${homeTeam} roster...`);
      homePlayersRaw = await espnRoster(ourTeamId, sport, league);
    }
    if (!oppApiId && oppName !== "TBD") {
      oppApiId = (await espnFindTeamId(oppName, sport, league)) ?? "";
    }
    if (oppApiId) {
      console.error(`      → Fetching ${oppName} roster...`);
      awayPlayersRaw = await espnRoster(oppApiId, sport, league);
    }
  } else if (sport === "baseball") {
    if (ourTeamId) {
      console.error(`      → Fetching ${homeTeam} roster...`);
      homePlayersRaw = await mlbRoster(ourTeamId);
    }
    if (oppName !== "TBD") {
      const oppMlbId = oppApiId || (await mlbFindTeamId(oppName)) || "";
      if (oppMlbId) {
        console.error(`      → Fetching ${oppName} roster...`);
        awayPlayersRaw = await mlbRoster(oppMlbId);
      }
    }
  } else if (sport === "hockey") {
    if (ourTeamId) {
      console.error(`      → Fetching ${homeTeam} roster...`);
      homePlayersRaw = await nhlRoster(ourTeamId);
    }
    if (oppName !== "TBD") {
      const oppAbbrev = oppApiId || nhlAbbrev(oppName) || "";
      if (oppAbbrev) {
        console.error(`      → Fetching ${oppName} roster...`);
        awayPlayersRaw = await nhlRoster(oppAbbrev);
      }
    }
  }

  console.error(`      → Home: ${homePlayersRaw.length} | Away: ${awayPlayersRaw.length}\n`);

  // ── 4. FETCH NEWS & INJURIES ───────────────────────────────────────────────
  console.error("[4/5] Fetching news & injuries via Google News RSS...");
  console.error(`      → Fetching injury report for ${homeTeam}...`);
  const homeInjuries = await fetchInjuryReport(homeTeam);
  console.error(`      → Fetching injury report for ${awayTeam}...`);
  const awayInjuries = awayTeam !== "TBD" ? await fetchInjuryReport(awayTeam) : [];
  const allInjuries = [...homeInjuries, ...awayInjuries];

  console.error(`      → Fetching latest news for ${homeTeam}...`);
  const homeNews = await fetchNewsForTeam(homeTeam);
  console.error(`      → Fetching latest news for ${awayTeam}...`);
  const awayNews = awayTeam !== "TBD" ? await fetchNewsForTeam(awayTeam) : [];
  let globalStorylines = [...homeNews.slice(0, 3), ...awayNews.slice(0, 2)];

  if ((sport === "soccer" || sport === "basketball") && ourTeamId) {
    const espnHeadlines = await espnTeamNews(ourTeamId, sport, league);
    globalStorylines = [...espnHeadlines.slice(0, 3), ...globalStorylines].slice(0, 8);
  }

  console.error(`      → ${globalStorylines.length} storylines, ${allInjuries.length} injury items\n`);

  // ── 5. BUILD PLAYER RECORDS ────────────────────────────────────────────────
  console.error("[5/5] Building player records...");
  const homeIdStr = makeId(homeTeam);
  const awayIdStr = makeId(awayTeam);

  async function buildPlayerList(
    playersRaw: RawPlayer[], teamIdStr: string,
    teamDisplay: string, opponentDisplay: string
  ): Promise<Player[]> {
    const built: Player[] = [];
    for (let i = 0; i < Math.min(playersRaw.length, 20); i++) {
      const p = playersRaw[i];
      const name     = p.name.trim() || `Player ${i + 1}`;
      const position = p.position || "";
      const age      = p.age ?? 0;
      const number   = p.number ?? (i + 1);
      const playerId = p.id || makeId(teamIdStr, name);

      let stats: Record<string, string> = {};
      if (i < 10 && playerId) {
        console.error(`      → Fetching stats for ${name}...`);
        if (sport === "soccer" || sport === "basketball") {
          stats = await espnPlayerStats(playerId, sport, league);
        } else if (sport === "baseball") {
          stats = await mlbPlayerStats(playerId);
        } else if (sport === "hockey") {
          stats = await nhlPlayerStats(playerId);
        }
      }

      let playerNews: string[] = [];
      if (i < 6) {
        console.error(`      → Fetching news for ${name}...`);
        playerNews = await fetchNewsForPlayer(name, teamDisplay);
      }

      const status = inferStatus(name, allInjuries);

      built.push({
        id:           makeId(teamIdStr, name),
        team_id:      teamIdStr,
        shirt_number: number,
        name,
        position:     position || "—",
        age,
        stats: {
          season:      stats,
          form_last_5: {},
          vs_opponent: {},
        },
        storyline:    makeStoryline(name, position, stats, playerNews, status),
        matchup_note: makeMatchupNote(name, opponentDisplay),
        top_stats:    topStats(stats),
        status,
        news_headlines: playerNews,
      });
    }
    return built;
  }

  const homePlayers = await buildPlayerList(homePlayersRaw, homeIdStr, homeTeam, awayTeam);
  const awayPlayers = await buildPlayerList(awayPlayersRaw, awayIdStr, awayTeam, homeTeam);

  console.error(
    `      → Built ${homePlayers.length} home + ${awayPlayers.length} away player records\n`
  );

  return {
    match: {
      id:          makeId(homeTeam, awayTeam),
      home_team:   homeTeam,
      away_team:   awayTeam,
      competition: gameInfo.competition || competitionDisplay,
      venue:       gameInfo.venue,
      kickoff_iso: gameInfo.date_iso || new Date().toISOString(),
    },
    teams: {
      home: { id: homeIdStr, name: homeTeam, color_hex: teamColor(homeTeam), record: {} },
      away: { id: awayIdStr, name: awayTeam, color_hex: teamColor(awayTeam), record: {} },
    },
    players:    [...homePlayers, ...awayPlayers],
    storylines: globalStorylines,
    source:     "espn_unofficial + mlb_official + nhl_official + google_news_rss",
    generated_at: new Date().toISOString(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  if (!args.length) {
    console.log("Usage: npx ts-node src/data/fetch_game.ts <team name>");
    console.log("  e.g. npx ts-node src/data/fetch_game.ts 'Manchester City'");
    console.log("  e.g. npx ts-node src/data/fetch_game.ts 'Los Angeles Lakers'");
    console.log("  e.g. npx ts-node src/data/fetch_game.ts 'New York Yankees'");
    console.log("  e.g. npx ts-node src/data/fetch_game.ts 'Toronto Maple Leafs'");
    process.exit(1);
  }

  const teamName = args.join(" ");

  try {
    const cache = await buildGameCache(teamName);

    const outDir = path.resolve(process.cwd(), "assets");
    fs.mkdirSync(outDir, { recursive: true });
    const outPath = path.join(outDir, "game_cache.json");
    fs.writeFileSync(outPath, JSON.stringify(cache, null, 2), "utf-8");

    console.log(`\n✓ Wrote ${outPath}`);
    console.log(`  Match:      ${cache.match.home_team} vs ${cache.match.away_team}`);
    console.log(`  Venue:      ${cache.match.venue}`);
    console.log(`  Kickoff:    ${cache.match.kickoff_iso}`);
    console.log(`  Players:    ${cache.players.length}`);
    console.log(`  Storylines: ${cache.storylines.length}`);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

main();
