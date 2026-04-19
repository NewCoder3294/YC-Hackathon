// Normalized tactics bundle. Soccer-focused for now — kept a minimal
// adapter interface so a second sport could plug in later, but all data
// here is from a single, auditable source: StatsBomb Open Data.

export type Sport = 'SOCCER';

export type MatchSummary = {
  id: string;
  sport: Sport;
  label: string;       // "Argentina 3-3 France"
  sublabel: string;    // "WC 2022 · FINAL · Dec 18 · Lusail"
  status: 'FINAL' | 'LIVE' | 'SCHEDULED';
  startTimeIso?: string;
};

export type TeamInfo = {
  id: string;
  name: string;
  code: string;      // 2-3 letter shorthand (ARG, FRA)
  color: string;
};

export type TacticsBundle = {
  sport: Sport;
  match: MatchSummary;
  home: TeamInfo;
  away: TeamInfo;
  topStats: { label: string; value: string }[];
  formation: FormationSection;
  pressing: PressingSection;
  xg: XGSection;
  possession: PossessionSection;
  shifts: ShiftsSection;
  keyEvents: KeyEvent[];
};

export type FormationSection = {
  home: TeamFormation;
  away: TeamFormation;
  takeaway: string;
};

export type TeamFormation = {
  team: TeamInfo;
  formation: string;          // "4-3-3"
  starters: PlayerDot[];
};

export type PlayerDot = {
  id: string;
  shirt: string;
  name: string;
  lastName: string;
  // Normalized 0..100, attacking toward y=100.
  x: number;
  y: number;
};

export type PressingSection = {
  home: PressingStats;
  away: PressingStats;
  takeaway: string;
};

export type PressingStats = {
  team: TeamInfo;
  ppda: number;
  // Defensive actions (Tackle + Interception + Block + Clearance + Duel) split by third.
  defHigh: number;            // attacking third (x >= 80 on StatsBomb's 0..120)
  defMid: number;             // middle (40..80)
  defLow: number;             // own third (0..40)
  // Pressures (separate type in StatsBomb) — included for context.
  pressuresHigh: number;
  pressuresMid: number;
};

export type XGSection = {
  home: TeamXG;
  away: TeamXG;
  takeaway: string;
};

export type TeamXG = {
  team: TeamInfo;
  xgTotal: number;
  xgOpenPlay: number;
  xgSetPiece: number;
  shots: number;
  shotsOnTarget: number;
  topShooter: { name: string; xg: number; shots: number } | null;
};

export type PossessionSection = {
  home: PossessionStats;
  away: PossessionStats;
  takeaway: string;
};

export type PossessionStats = {
  team: TeamInfo;
  passes: number;
  passAccuracy: number;       // 0..1
  // Share of match passes attempted by this team.
  possessionShare: number;    // 0..1
  progressivePasses: number;  // passes whose (end_x - start_x) >= 10m into opp half
};

export type ShiftsSection = {
  events: ShiftEvent[];
  takeaway: string;
};

export type ShiftEvent = {
  minute: number;
  teamCode: string;
  from?: string;      // previous formation if derivable
  to: string;
  note: string;
};

export type KeyEvent = {
  minute: number;
  teamCode: string;
  kind: 'GOAL' | 'OWN_GOAL' | 'PEN' | 'RED' | 'SUB' | 'VAR';
  headline: string;
  detail: string;
};

export type SportAdapter = {
  sport: Sport;
  listMatches(): Promise<MatchSummary[]>;
  loadMatch(matchId: string): Promise<TacticsBundle>;
};
