import { scoreboardUrl, playByPlayUrl, type League } from "./sports.js";

function extractId(url: string | undefined): string | undefined {
  if (!url) return undefined;
  const m = url.match(/\/(?:teams|athletes|positions)\/(\d+)/);
  return m?.[1];
}

export interface Game {
  id: string;
  name: string;
  shortName: string;
  status: string;
  statusDetail: string;
  homeTeam: string;
  awayTeam: string;
  homeScore: string;
  awayScore: string;
  period: string;
  homeTeamId?: string;
  awayTeamId?: string;
  homeTeamAbbr?: string;
  awayTeamAbbr?: string;
}

export interface Play {
  id: string;
  sequenceNumber?: string;
  period?: { number?: number; type?: string; displayValue?: string };
  awayScore?: number;
  homeScore?: number;
  type?: { text?: string };
  text?: string;
  participants?: Array<{ athlete?: { displayName?: string; $ref?: string }; type?: string }>;
  scoringPlay?: boolean;
  [key: string]: unknown;
}

async function fetchJson(url: string): Promise<unknown> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.json();
}

export async function getLiveGames(league: League): Promise<Game[]> {
  const data = (await fetchJson(scoreboardUrl(league))) as {
    events?: Array<{
      id: string;
      name: string;
      shortName: string;
      competitions: Array<{
        competitors: Array<{
          id: string;
          homeAway: string;
          team: { displayName: string; abbreviation?: string };
          score: string;
        }>;
        status: { type: { description: string; detail: string } };
      }>;
    }>;
  };

  return (data.events ?? []).map((event) => {
    const comp = event.competitions[0];
    const home = comp.competitors.find((c) => c.homeAway === "home")!;
    const away = comp.competitors.find((c) => c.homeAway === "away")!;
    return {
      id: event.id,
      name: event.name,
      shortName: event.shortName,
      status: comp.status.type.description,
      statusDetail: comp.status.type.detail,
      homeTeam: home.team.displayName,
      awayTeam: away.team.displayName,
      homeScore: home.score ?? "0",
      awayScore: away.score ?? "0",
      period: comp.status.type.detail,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeTeamAbbr: home.team.abbreviation,
      awayTeamAbbr: away.team.abbreviation,
    };
  });
}

export async function getPlays(league: League, gameId: string): Promise<Play[]> {
  const data = (await fetchJson(playByPlayUrl(league, gameId))) as { items?: Play[] };
  return data.items ?? [];
}

export function filterNewPlays(allPlays: Play[], lastPlayId: string | null): Play[] {
  if (!lastPlayId) return allPlays;
  const lastIndex = allPlays.findIndex((p) => p.id === lastPlayId);
  return lastIndex === -1 ? allPlays : allPlays.slice(lastIndex + 1);
}

const athleteCache = new Map<string, any>();

export async function enrichPlaysWithAthletes(plays: Play[]): Promise<Play[]> {
  const athleteUrls = new Set<string>();

  plays.forEach((play) => {
    play.participants?.forEach((p) => {
      const ref = p.athlete?.$ref;
      if (ref) athleteUrls.add(ref);
    });
  });

  const urlsToFetch = Array.from(athleteUrls).filter((u) => !athleteCache.has(u));
  if (urlsToFetch.length > 0) {
    console.log(`  Fetching ${urlsToFetch.length} athlete profiles...`);
    let fetched = 0;
    for (const url of urlsToFetch) {
      try {
        athleteCache.set(url, await fetchJson(url));
        fetched++;
      } catch {
        console.warn(`  ⚠ Failed to fetch athlete: ${url}`);
      }
    }
    console.log(`  ✓ Cached ${fetched} athletes`);
  }

  return plays.map((play) => ({
    ...play,
    participants: play.participants?.map((p: any) => {
      const ref = p.athlete?.$ref;
      if (ref && athleteCache.has(ref)) {
        const a = athleteCache.get(ref);
        return {
          ...p,
          athlete: {
            id: a.id,
            displayName: a.displayName,
            fullName: a.fullName,
            jerseyNumber: a.jersey,
            position: a.position,
          },
        };
      }
      return p;
    }),
  }));
}

function compactParticipant(p: any, athletes: Record<string, any>): any {
  const id = p.athlete?.id ?? extractId(p.athlete?.$ref);
  if (id && p.athlete?.displayName && !athletes[id]) {
    athletes[id] = {
      name: p.athlete.displayName,
      jersey: p.athlete.jerseyNumber,
      position: p.athlete.position?.abbreviation ?? p.athlete.position?.displayName,
    };
  }
  const out: any = {};
  if (id) out.athleteId = id;
  if (p.type) out.type = p.type;
  if (p.order != null) out.order = p.order;
  return out;
}

function cleanBaseball(p: any, out: any): void {
  if (p.pitchCoordinate) out.pitchCoordinate = p.pitchCoordinate;
  if (p.pitchType?.text) out.pitchType = p.pitchType.text;
  if (p.pitchVelocity) out.pitchVelocity = p.pitchVelocity;
  if (p.hitCoordinate) out.hitCoordinate = p.hitCoordinate;
  if (p.trajectory) out.trajectory = p.trajectory;
  if (p.atBatId) out.atBatId = p.atBatId;
  if (p.batOrder != null) out.batOrder = p.batOrder;
  if (p.atBatPitchNumber != null) out.atBatPitchNumber = p.atBatPitchNumber;
  if (p.bats?.abbreviation) out.bats = p.bats.abbreviation;
  if (p.pitches?.abbreviation) out.pitches = p.pitches.abbreviation;
  if (p.pitchCount) out.pitchCount = p.pitchCount;
  if (p.outs) out.outs = p.outs;
  if (p.rbiCount) out.rbiCount = p.rbiCount;
  if (p.awayHits) out.awayHits = p.awayHits;
  if (p.homeHits) out.homeHits = p.homeHits;
  if (p.awayErrors) out.awayErrors = p.awayErrors;
  if (p.homeErrors) out.homeErrors = p.homeErrors;
  if (p.doublePlay) out.doublePlay = true;
  if (p.triplePlay) out.triplePlay = true;
  if (p.summaryType) out.summaryType = p.summaryType;
}

function cleanBasketball(p: any, out: any): void {
  if (p.coordinate && p.coordinate.x !== -214748340 && p.coordinate.y !== -214748365) {
    out.coordinate = p.coordinate;
  }
  if (p.pointsAttempted) out.pointsAttempted = p.pointsAttempted;
  if (p.shootingPlay) out.shootingPlay = true;
}

function cleanFootball(p: any, out: any): void {
  const hasStart =
    p.start && (p.start.down || p.start.distance || p.start.yardLine || p.start.yardsToEndzone);
  if (hasStart) {
    const s: any = {};
    if (p.start.down) s.down = p.start.down;
    if (p.start.distance) s.distance = p.start.distance;
    if (p.start.yardLine) s.yardLine = p.start.yardLine;
    if (p.start.yardsToEndzone) s.yardsToEndzone = p.start.yardsToEndzone;
    const tid = extractId(p.start.team?.$ref);
    if (tid) s.teamId = tid;
    out.start = s;
  }
  const hasEnd =
    p.end && (p.end.down || p.end.distance || p.end.yardLine || p.end.yardsToEndzone);
  if (hasEnd) {
    const e: any = {};
    if (p.end.down) e.down = p.end.down;
    if (p.end.distance) e.distance = p.end.distance;
    if (p.end.yardLine) e.yardLine = p.end.yardLine;
    if (p.end.yardsToEndzone) e.yardsToEndzone = p.end.yardsToEndzone;
    if (p.end.shortDownDistanceText) e.downDistance = p.end.shortDownDistanceText;
    if (p.end.possessionText) e.possession = p.end.possessionText;
    const tid = extractId(p.end.team?.$ref);
    if (tid) e.teamId = tid;
    out.end = e;
  }
  if (p.statYardage) out.statYardage = p.statYardage;
  if (p.isTurnover) out.isTurnover = true;
  if (p.teamParticipants?.length) {
    out.teamParticipants = p.teamParticipants.map((t: any) => {
      const tp: any = { teamId: t.id ?? extractId(t.team?.$ref) };
      if (t.order != null) tp.order = t.order;
      if (t.type) tp.type = t.type;
      return tp;
    });
  }
}

function cleanHockey(p: any, out: any): void {
  if (p.strength?.text) out.strength = p.strength.text;
  if (p.isPenalty) out.isPenalty = true;
  if (p.shootingPlay) out.shootingPlay = true;
}

function cleanSoccer(p: any, out: any): void {
  if (p.redCard) out.redCard = true;
  if (p.yellowCard) out.yellowCard = true;
  if (p.penaltyKick) out.penaltyKick = true;
  if (p.ownGoal) out.ownGoal = true;
  if (p.shootout) out.shootout = true;
  if (p.substitution) out.substitution = true;
  if (p.addedClock?.value) out.addedClock = p.addedClock.value;
  if (p.fieldPositionX || p.fieldPositionY) {
    out.fieldPosition = { x: p.fieldPositionX, y: p.fieldPositionY };
  }
  if (p.fieldPosition2X || p.fieldPosition2Y) {
    out.fieldPosition2 = { x: p.fieldPosition2X, y: p.fieldPosition2Y };
  }
  if (p.goalPositionX || p.goalPositionY || p.goalPositionZ) {
    out.goalPosition = { x: p.goalPositionX, y: p.goalPositionY, z: p.goalPositionZ };
  }
}

function compactPlay(p: any, sport: string, athletes: Record<string, any>): any {
  const out: any = { id: p.id };
  if (p.sequenceNumber) out.seq = p.sequenceNumber;
  if (p.type?.text) out.type = p.type.text;
  if (p.text) out.text = p.text;
  if (p.awayScore != null) out.awayScore = p.awayScore;
  if (p.homeScore != null) out.homeScore = p.homeScore;
  if (p.clock?.displayValue) out.clock = p.clock.displayValue;
  if (p.scoringPlay) out.scoringPlay = true;
  if (p.scoreValue) out.scoreValue = p.scoreValue;
  if (p.wallclock) out.wallclock = p.wallclock;
  const teamId = extractId(p.team?.$ref);
  if (teamId) out.teamId = teamId;

  if (p.participants?.length) {
    out.participants = p.participants.map((x: any) => compactParticipant(x, athletes));
  }

  if (sport === "baseball") cleanBaseball(p, out);
  else if (sport === "basketball") cleanBasketball(p, out);
  else if (sport === "football") cleanFootball(p, out);
  else if (sport === "hockey") cleanHockey(p, out);
  else if (sport === "soccer") cleanSoccer(p, out);

  return out;
}

export interface CompactGame {
  league: Pick<League, "key" | "sport" | "league">;
  game: {
    id: string;
    name: string;
    shortName: string;
    status: string;
    statusDetail: string;
    awayTeam: string;
    homeTeam: string;
    awayScore: string;
    homeScore: string;
  };
  totalPlays: number;
  athletes: Record<string, { name: string; jersey?: string; position?: string }>;
  teams: Record<string, { name?: string; abbreviation?: string }>;
  periods: Array<{ number: number; type?: string; displayValue?: string; plays: any[] }>;
}

export function compactGame(league: League, game: Game, plays: Play[]): CompactGame {
  const athletes: Record<string, any> = {};
  const teams: Record<string, any> = {};

  if (game.homeTeamId) teams[game.homeTeamId] = { name: game.homeTeam, abbreviation: game.homeTeamAbbr };
  if (game.awayTeamId) teams[game.awayTeamId] = { name: game.awayTeam, abbreviation: game.awayTeamAbbr };

  const periodMap = new Map<
    string,
    { number: number; type?: string; displayValue?: string; plays: any[] }
  >();

  for (const p of plays) {
    const period = (p as any).period ?? {};
    const key = `${period.number ?? 0}|${period.type ?? ""}`;
    if (!periodMap.has(key)) {
      periodMap.set(key, {
        number: period.number ?? 0,
        type: period.type,
        displayValue: period.displayValue,
        plays: [],
      });
    }
    periodMap.get(key)!.plays.push(compactPlay(p, league.sport, athletes));
  }

  return {
    league: { key: league.key, sport: league.sport, league: league.league },
    game: {
      id: game.id,
      name: game.name,
      shortName: game.shortName,
      status: game.status,
      statusDetail: game.statusDetail,
      awayTeam: game.awayTeam,
      homeTeam: game.homeTeam,
      awayScore: game.awayScore,
      homeScore: game.homeScore,
    },
    totalPlays: plays.length,
    athletes,
    teams,
    periods: Array.from(periodMap.values()),
  };
}

export function lastCompactPlayId(data: CompactGame | null): string | null {
  if (!data?.periods?.length) return null;
  for (let i = data.periods.length - 1; i >= 0; i--) {
    const plays = data.periods[i].plays;
    if (plays.length > 0) return plays[plays.length - 1].id;
  }
  return null;
}
