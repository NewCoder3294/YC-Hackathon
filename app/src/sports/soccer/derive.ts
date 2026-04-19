// Derive normalized tactics from StatsBomb Open events + lineups + match meta.
// All numbers are aggregated from real events. Formulas noted inline.

import {
  FormationSection,
  KeyEvent,
  MatchSummary,
  PlayerDot,
  PossessionSection,
  PossessionStats,
  PressingSection,
  PressingStats,
  ShiftEvent,
  ShiftsSection,
  TacticsBundle,
  TeamFormation,
  TeamInfo,
  TeamXG,
  XGSection,
} from '../types';
import { SBEvent, SBLineup, SBMatchMeta } from './adapter';

// StatsBomb pitch is 120 (x, goal-line to goal-line) × 80 (y).
const PITCH_LEN = 120;
const PITCH_WID = 80;

// Third thresholds for press + xG stratification.
const HIGH_X = 80;       // x >= 80 = attacking third
const MID_X = 40;        // 40..80 = middle third
// Opp-half threshold used for PPDA.
const OPP_HALF_X = 60;

const HOME_COLOR = '#7DD3FC';
const AWAY_COLOR = '#F9A8D4';

// ── Canonical StatsBomb position_id → pitch coordinates.
// Source: https://github.com/statsbomb/open-data/blob/master/doc/Open%20Data%20Events%20v4.0.0.pdf
// (x axis = 0..120 attacking right, y axis = 0..80).
// We store canonical (x,y) in StatsBomb space and normalize to 0..100 for rendering.
const SB_POSITION_COORDS: Record<number, { x: number; y: number }> = {
  1:  { x: 10,  y: 40 },   // Goalkeeper
  2:  { x: 25,  y: 65 },   // Right Back
  3:  { x: 25,  y: 50 },   // Right Center Back
  4:  { x: 25,  y: 40 },   // Center Back
  5:  { x: 25,  y: 30 },   // Left Center Back
  6:  { x: 25,  y: 15 },   // Left Back
  7:  { x: 40,  y: 68 },   // Right Wing Back
  8:  { x: 40,  y: 12 },   // Left Wing Back
  9:  { x: 45,  y: 60 },   // Right Defensive Midfield
  10: { x: 45,  y: 40 },   // Center Defensive Midfield
  11: { x: 45,  y: 20 },   // Left Defensive Midfield
  12: { x: 70,  y: 68 },   // Right Midfield
  13: { x: 60,  y: 55 },   // Right Center Midfield
  14: { x: 60,  y: 40 },   // Center Midfield
  15: { x: 60,  y: 25 },   // Left Center Midfield
  16: { x: 70,  y: 12 },   // Left Midfield
  17: { x: 95,  y: 68 },   // Right Wing
  18: { x: 80,  y: 55 },   // Right Attacking Midfield
  19: { x: 80,  y: 40 },   // Center Attacking Midfield
  20: { x: 80,  y: 25 },   // Left Attacking Midfield
  21: { x: 95,  y: 12 },   // Left Wing
  22: { x: 105, y: 50 },   // Right Center Forward
  23: { x: 110, y: 40 },   // Striker
  24: { x: 105, y: 30 },   // Left Center Forward
  25: { x: 95,  y: 40 },   // Secondary Striker
};

export function deriveBundle(args: {
  curated: { matchId: string; label: string; venue: string };
  meta: SBMatchMeta;
  events: SBEvent[];
  lineups: SBLineup[];
}): TacticsBundle {
  const { curated, meta, events, lineups } = args;

  // Canonical home/away from match metadata — NEVER infer from lineups order.
  const homeTeamId = meta.home_team.home_team_id;
  const awayTeamId = meta.away_team.away_team_id;

  const home: TeamInfo = {
    id: String(homeTeamId),
    name: meta.home_team.home_team_name,
    code: teamCode(meta.home_team.home_team_name),
    color: HOME_COLOR,
  };
  const away: TeamInfo = {
    id: String(awayTeamId),
    name: meta.away_team.away_team_name,
    code: teamCode(meta.away_team.away_team_name),
    color: AWAY_COLOR,
  };

  const match: MatchSummary = {
    id: curated.matchId,
    sport: 'SOCCER',
    label: `${home.name} ${meta.home_score}-${meta.away_score} ${away.name}`,
    sublabel: `${curated.label} · ${curated.venue}`,
    status: 'FINAL',
    startTimeIso: meta.match_date,
  };

  const formation = deriveFormation(events, home, away);
  const pressing = derivePressing(events, home, away);
  const xg = deriveXG(events, home, away);
  const possession = derivePossession(events, home, away);
  const shifts = deriveShifts(events, home, away);
  const keyEvents = deriveKeyEvents(events, home, away);

  const topStats = [
    { label: 'FORMATIONS', value: `${formation.home.formation} · ${formation.away.formation}` },
    { label: 'TOTAL xG', value: `${xg.home.xgTotal.toFixed(2)} - ${xg.away.xgTotal.toFixed(2)}` },
    { label: 'SHOTS', value: `${xg.home.shots} - ${xg.away.shots}` },
    { label: 'POSSESSION', value: `${Math.round(possession.home.possessionShare * 100)}% - ${Math.round(possession.away.possessionShare * 100)}%` },
  ];

  return {
    sport: 'SOCCER',
    match,
    home,
    away,
    topStats,
    formation,
    pressing,
    xg,
    possession,
    shifts,
    keyEvents,
  };
}

function teamCode(name: string): string {
  const words = name.replace(/[^A-Za-z ]/g, '').split(/\s+/).filter(Boolean);
  if (words.length === 1) return words[0].slice(0, 3).toUpperCase();
  return (words[0][0] + (words[1]?.[0] ?? words[0][1] ?? '')).toUpperCase();
}

// ── Formation: first Starting XI event per team. Positions come from the
// canonical position_id map above — not a keyword heuristic. ──
function deriveFormation(events: SBEvent[], home: TeamInfo, away: TeamInfo): FormationSection {
  const starting = events.filter((e) => e.type?.name === 'Starting XI');
  const homeStart = starting.find((e) => String(e.team.id) === home.id);
  const awayStart = starting.find((e) => String(e.team.id) === away.id);
  const hForm = startingToFormation(homeStart, home);
  const aForm = startingToFormation(awayStart, away);
  return {
    home: hForm,
    away: aForm,
    takeaway: `${home.code} ${hForm.formation} vs ${away.code} ${aForm.formation}. ` +
      `Shape + player coordinates pulled from the Starting XI event in StatsBomb.`,
  };
}

function startingToFormation(e: SBEvent | undefined, team: TeamInfo): TeamFormation {
  if (!e?.tactics) return { team, formation: '—', starters: [] };
  const formation = prettyFormation(String(e.tactics.formation));
  const starters: PlayerDot[] = e.tactics.lineup.map((p) => {
    const coords = SB_POSITION_COORDS[p.position.id] ?? { x: 60, y: 40 };
    // StatsBomb pitch: x=0..120 (goal-line to goal-line, attacking right),
    //                   y=0..80 (left touchline to right touchline).
    // Our render: both teams attacking up the screen.
    //   render x (0..100) = left flank → right flank = SB y / 80
    //   render y (0..100) = own goal → opp goal      = SB x / 120
    return {
      id: String(p.player.id),
      shirt: String(p.jersey_number),
      name: p.player.name,
      lastName: p.player.name.split(' ').slice(-1)[0],
      x: Math.round((coords.y / PITCH_WID) * 100),
      y: Math.round((coords.x / PITCH_LEN) * 100),
    };
  });
  return { team, formation, starters };
}

function prettyFormation(code: string): string {
  // Strip trailing zeros StatsBomb sometimes includes (e.g. "4411" = 4-4-1-1).
  return code.split('').join('-');
}

// ── Pressing: industry-standard PPDA + defensive-third split. ──
// PPDA = opponent passes attempted in their own build-up 3/5 of the pitch
// divided by own team defensive actions (Tackle / Interception / Foul Committed / Duel)
// committed in the opponent's 3/5 of the pitch.
function derivePressing(events: SBEvent[], home: TeamInfo, away: TeamInfo): PressingSection {
  const hPress = computePressing(events, home, away);
  const aPress = computePressing(events, away, home);
  const harderPress =
    hPress.ppda < aPress.ppda ? home.code : aPress.ppda < hPress.ppda ? away.code : 'EVEN';
  return {
    home: hPress,
    away: aPress,
    takeaway:
      `${harderPress === 'EVEN' ? 'Even press intensity' : harderPress + ' pressed more aggressively'}. ` +
      `PPDA = opponent passes in their own ${Math.round((OPP_HALF_X / PITCH_LEN) * 100)}% of the pitch ÷ ` +
      `own defensive actions (tackles + interceptions + blocks + duels + fouls) in opp half.`,
  };
}

function computePressing(events: SBEvent[], ownTeam: TeamInfo, oppTeam: TeamInfo): PressingStats {
  const defTypes = new Set(['Duel', 'Interception', 'Block', 'Tackle', 'Clearance', 'Foul Committed']);

  let defHigh = 0, defMid = 0, defLow = 0;
  let pressuresHigh = 0, pressuresMid = 0;

  for (const e of events) {
    if (String(e.team.id) !== ownTeam.id) continue;
    const x = e.location?.[0] ?? -1;
    if (x < 0) continue;
    if (defTypes.has(e.type.name)) {
      if (x >= HIGH_X) defHigh += 1;
      else if (x >= MID_X) defMid += 1;
      else defLow += 1;
    }
    if (e.type.name === 'Pressure') {
      if (x >= HIGH_X) pressuresHigh += 1;
      else if (x >= MID_X) pressuresMid += 1;
    }
  }

  // PPDA numerator: opponent passes in their own build-up 3/5.
  // Their own x-coordinate from their perspective = PITCH_LEN - SB x (events
  // are recorded attacking-toward-x=120 for whichever team has the ball).
  let oppPassesDeep = 0;
  let ownDefActionsHigh = 0;
  for (const e of events) {
    const x = e.location?.[0] ?? -1;
    if (x < 0) continue;
    if (String(e.team.id) === oppTeam.id && e.type.name === 'Pass' && !e.pass?.outcome) {
      // Opponent's own defensive 3/5: their x < OPP_HALF_X (they are attacking
      // toward x=120, so low x = their own half).
      if (x < OPP_HALF_X) oppPassesDeep += 1;
    }
    if (String(e.team.id) === ownTeam.id && defTypes.has(e.type.name) && x >= OPP_HALF_X) {
      ownDefActionsHigh += 1;
    }
  }
  const ppda = ownDefActionsHigh === 0 ? 99.9 : Math.round((oppPassesDeep / ownDefActionsHigh) * 10) / 10;

  return {
    team: ownTeam,
    ppda,
    defHigh,
    defMid,
    defLow,
    pressuresHigh,
    pressuresMid,
  };
}

// ── xG: sum of statsbomb_xg on every Shot event. Split open-play vs set-piece. ──
function deriveXG(events: SBEvent[], home: TeamInfo, away: TeamInfo): XGSection {
  const h = aggregateXG(events, home);
  const a = aggregateXG(events, away);
  const takeaway =
    h.xgTotal === a.xgTotal
      ? `Even xG (${h.xgTotal.toFixed(2)}). Set-piece xG split: ${home.code} ${h.xgSetPiece.toFixed(2)} vs ${away.code} ${a.xgSetPiece.toFixed(2)}.`
      : h.xgTotal > a.xgTotal
        ? `${home.code} out-chanced ${away.code} ${h.xgTotal.toFixed(2)} to ${a.xgTotal.toFixed(2)} xG.`
        : `${away.code} out-chanced ${home.code} ${a.xgTotal.toFixed(2)} to ${h.xgTotal.toFixed(2)} xG.`;
  return { home: h, away: a, takeaway };
}

function aggregateXG(events: SBEvent[], team: TeamInfo): TeamXG {
  const onTarget = new Set(['Goal', 'Saved', 'Saved To Post', 'Saved Off T']);
  const setPieceTypes = new Set(['Penalty', 'Free Kick', 'Corner']);

  let xgTotal = 0, xgOpenPlay = 0, xgSetPiece = 0, shots = 0, shotsOnTarget = 0;
  const byPlayer = new Map<string, { xg: number; shots: number }>();

  for (const e of events) {
    if (String(e.team.id) !== team.id) continue;
    if (e.type.name !== 'Shot' || !e.shot) continue;
    shots += 1;
    xgTotal += e.shot.statsbomb_xg;
    if (onTarget.has(e.shot.outcome.name)) shotsOnTarget += 1;
    const isSet = e.shot.type ? setPieceTypes.has(e.shot.type.name) : false;
    if (isSet) xgSetPiece += e.shot.statsbomb_xg;
    else xgOpenPlay += e.shot.statsbomb_xg;
    if (e.player) {
      const cur = byPlayer.get(e.player.name) ?? { xg: 0, shots: 0 };
      cur.xg += e.shot.statsbomb_xg;
      cur.shots += 1;
      byPlayer.set(e.player.name, cur);
    }
  }
  let topShooter: TeamXG['topShooter'] = null;
  for (const [name, v] of byPlayer.entries()) {
    if (!topShooter || v.xg > topShooter.xg) {
      topShooter = { name, xg: Math.round(v.xg * 100) / 100, shots: v.shots };
    }
  }

  return {
    team,
    xgTotal: Math.round(xgTotal * 100) / 100,
    xgOpenPlay: Math.round(xgOpenPlay * 100) / 100,
    xgSetPiece: Math.round(xgSetPiece * 100) / 100,
    shots,
    shotsOnTarget,
    topShooter,
  };
}

// ── Possession + progressive passes ──
function derivePossession(events: SBEvent[], home: TeamInfo, away: TeamInfo): PossessionSection {
  const h = teamPossession(events, home);
  const a = teamPossession(events, away);
  const totalPasses = h.passes + a.passes || 1;
  h.possessionShare = h.passes / totalPasses;
  a.possessionShare = a.passes / totalPasses;
  const dominantPasser = h.passes >= a.passes ? home.code : away.code;
  return {
    home: h,
    away: a,
    takeaway: `${dominantPasser} had more of the ball (passes attempted proxy). ` +
      `Progressive passes count every completion whose x-gain is ≥ 10m into the opposition half.`,
  };
}

function teamPossession(events: SBEvent[], team: TeamInfo): PossessionStats {
  let passes = 0, completed = 0, progressive = 0;
  for (const e of events) {
    if (String(e.team.id) !== team.id) continue;
    if (e.type.name !== 'Pass' || !e.pass) continue;
    passes += 1;
    const wasCompleted = !e.pass.outcome;
    if (wasCompleted) completed += 1;
    // Progressive: positive x delta ≥ 10 (StatsBomb metres ≈ yards on a 120×80 pitch).
    const sx = e.location?.[0] ?? 0;
    const ex = e.pass.end_location?.[0] ?? 0;
    if (wasCompleted && ex - sx >= 10 && ex >= OPP_HALF_X) progressive += 1;
  }
  return {
    team,
    passes,
    passAccuracy: passes === 0 ? 0 : Math.round((completed / passes) * 1000) / 1000,
    possessionShare: 0,
    progressivePasses: progressive,
  };
}

// ── Tactical shifts (StatsBomb event type "Tactical Shift") ──
function deriveShifts(events: SBEvent[], home: TeamInfo, away: TeamInfo): ShiftsSection {
  const shifts: ShiftEvent[] = [];
  const lastFormation = new Map<string, string>(); // teamId → last formation seen
  // Seed with the starting XI formations
  for (const e of events) {
    if (e.type.name === 'Starting XI' && e.tactics) {
      lastFormation.set(String(e.team.id), prettyFormation(String(e.tactics.formation)));
    }
  }
  for (const e of events) {
    if (e.type.name !== 'Tactical Shift' || !e.tactics) continue;
    const teamId = String(e.team.id);
    const prev = lastFormation.get(teamId);
    const to = prettyFormation(String(e.tactics.formation));
    if (prev && prev !== to) {
      shifts.push({
        minute: e.minute,
        teamCode: teamId === home.id ? home.code : away.code,
        from: prev,
        to,
        note: `Tactical Shift event at ${e.minute}'.`,
      });
      lastFormation.set(teamId, to);
    }
  }
  return {
    events: shifts,
    takeaway:
      shifts.length === 0
        ? 'No tactical shifts recorded — shape held from kickoff through full time.'
        : `${shifts.length} tactical shift${shifts.length === 1 ? '' : 's'} fired during the match.`,
  };
}

// ── Key events: goals, red cards, penalties ──
function deriveKeyEvents(events: SBEvent[], home: TeamInfo, away: TeamInfo): KeyEvent[] {
  const out: KeyEvent[] = [];
  for (const e of events) {
    const teamCode = String(e.team.id) === home.id ? home.code : away.code;
    // Goal
    if (e.type.name === 'Shot' && e.shot?.outcome?.name === 'Goal') {
      const kind: KeyEvent['kind'] = e.shot.type?.name === 'Penalty' ? 'PEN' : 'GOAL';
      out.push({
        minute: e.minute,
        teamCode,
        kind,
        headline: `${e.minute}' ${e.player?.name ?? 'Unknown'}`,
        detail: `${kind === 'PEN' ? 'Penalty' : 'Open play'} · xG ${e.shot.statsbomb_xg.toFixed(2)} · ${e.shot.body_part?.name ?? '—'}`,
      });
    }
    // Own goal: StatsBomb records "Own Goal For" / "Own Goal Against"
    if (e.type.name === 'Own Goal For') {
      out.push({
        minute: e.minute,
        teamCode,
        kind: 'OWN_GOAL',
        headline: `${e.minute}' Own goal`,
        detail: `Credited to ${teamCode}.`,
      });
    }
    // Red card — in StatsBomb these are Bad Behaviour / Foul Committed events with card type
    if (e.type.name === 'Bad Behaviour' || e.type.name === 'Foul Committed') {
      // A card field is nested under the specific event type in the StatsBomb
      // schema; we only flag if we can detect it via a pass-through "card" prop.
      const card = (e as unknown as { foul_committed?: { card?: { name: string } } }).foul_committed?.card?.name;
      if (card && /Red/.test(card)) {
        out.push({
          minute: e.minute,
          teamCode,
          kind: 'RED',
          headline: `${e.minute}' Red card`,
          detail: `${e.player?.name ?? 'Unknown'} · ${card}.`,
        });
      }
    }
  }
  return out.sort((a, b) => a.minute - b.minute);
}
