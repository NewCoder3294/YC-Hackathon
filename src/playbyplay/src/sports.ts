export interface League {
  key: string;
  sport: string;
  league: string;
  displayName: string;
}

export const LEAGUES: League[] = [
  { key: "mlb", sport: "baseball", league: "mlb", displayName: "MLB — Baseball" },
  { key: "nba", sport: "basketball", league: "nba", displayName: "NBA — Basketball" },
  { key: "wnba", sport: "basketball", league: "wnba", displayName: "WNBA — Basketball" },
  { key: "ncaam", sport: "basketball", league: "mens-college-basketball", displayName: "NCAAM — College Basketball" },
  { key: "ncaaw", sport: "basketball", league: "womens-college-basketball", displayName: "NCAAW — College Basketball" },
  { key: "nfl", sport: "football", league: "nfl", displayName: "NFL — Football" },
  { key: "ncaaf", sport: "football", league: "college-football", displayName: "NCAAF — College Football" },
  { key: "nhl", sport: "hockey", league: "nhl", displayName: "NHL — Hockey" },
  { key: "epl", sport: "soccer", league: "eng.1", displayName: "EPL — Soccer" },
  { key: "laliga", sport: "soccer", league: "esp.1", displayName: "La Liga — Soccer" },
  { key: "seriea", sport: "soccer", league: "ita.1", displayName: "Serie A — Soccer" },
  { key: "bundesliga", sport: "soccer", league: "ger.1", displayName: "Bundesliga — Soccer" },
  { key: "ligue1", sport: "soccer", league: "fra.1", displayName: "Ligue 1 — Soccer" },
  { key: "ucl", sport: "soccer", league: "uefa.champions", displayName: "UEFA Champions League — Soccer" },
  { key: "mls", sport: "soccer", league: "usa.1", displayName: "MLS — Soccer" },
];

export function scoreboardUrl(l: League): string {
  return `https://site.api.espn.com/apis/site/v2/sports/${l.sport}/${l.league}/scoreboard`;
}

export function playByPlayUrl(l: League, gameId: string, limit = 1000): string {
  return `https://sports.core.api.espn.com/v2/sports/${l.sport}/leagues/${l.league}/events/${gameId}/competitions/${gameId}/plays?limit=${limit}`;
}
