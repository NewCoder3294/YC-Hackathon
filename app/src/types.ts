// Feature 1 shared types — mirror frontend/DATA_CONTRACTS.md shapes (trimmed for UI).

export type Mode = 'STATS' | 'STORY' | 'TACTICAL';
export type Density = 'COMPACT' | 'STANDARD' | 'FULL';
export type Position = 'GK' | 'DF' | 'MF' | 'FW';
export type Nation = 'ARG' | 'FRA';

export type PlayerCellData = {
  id: string;
  n: string;                    // jersey number as string (can include leading space)
  pos: string;                  // "FW", "MF · CAM", etc.
  nation: Nation;
  name: string;

  // STATS projection
  xg?: string;
  xa?: string;
  prog?: number;
  pressures?: number;
  shotAcc?: string;
  rank?: string;                // e.g. "TOP-3 WC xG"

  // STORY projection
  age?: number;
  storyHero?: string;
  storyLines?: string[];

  // TACTICAL projection
  role?: string;
  formationRole?: string;       // "4-3-3 · FREE 10"
  pressingMap?: string;         // "PASSIVE" / "HIGH" / etc.
  defActions?: number;
  keyPasses?: number;

  // Personalization state
  pinned?: boolean;
  highlight?: boolean;
  annotation?: string | null;
};

export type ModeOptionSpec = {
  id: Mode;
  label: string;
  sub: string;
  hint: string;
  recommended?: boolean;
};
