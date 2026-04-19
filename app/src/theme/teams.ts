// Team branding registry — colors + flag/crest metadata keyed by team id.
// National teams use FIFA 3-letter codes (ARG, FRA). MLS/MLB/clubs use a
// league-prefixed id (MLS-LAFC, MLB-NYY, EUR-BAR) so short codes can collide
// safely across leagues.

export type FlagPattern =
  | { kind: 'hs3'; colors: [string, string, string] }   // horizontal 3-stripe
  | { kind: 'vs3'; colors: [string, string, string] }   // vertical 3-stripe
  | { kind: 'hs2'; colors: [string, string] }           // horizontal 2-stripe
  | { kind: 'vs2'; colors: [string, string] }           // vertical 2-stripe
  | { kind: 'nordic'; bg: string; cross: string }       // Nordic cross
  | { kind: 'disc'; bg: string; disc: string }          // solid + centered disc
  | { kind: 'canton'; base: string; canton: string }    // simplified canton
  | { kind: 'solid'; color: string };                   // plain color

export type League = 'intl' | 'mls' | 'mlb' | 'eur';

export type TeamBrand = {
  id: string;
  name: string;
  abbr: string;
  league: League;
  primary: string;    // dominant brand color (surfaces + accent bars)
  secondary: string;  // support color (text on primary, highlights)
  flag?: FlagPattern;
};

function mkTeams<K extends string>(base: Record<K, Omit<TeamBrand, 'id'>>): Record<K, TeamBrand> {
  const out = {} as Record<K, TeamBrand>;
  (Object.keys(base) as K[]).forEach((k) => { out[k] = { ...base[k], id: k }; });
  return out;
}

export const TEAMS = mkTeams({
  // ═══════════════════════════════ NATIONAL (FIFA) ═══════════════════════════════
  ARG: { name: 'Argentina',     abbr: 'ARG', league: 'intl', primary: '#6CACE4', secondary: '#FFFFFF', flag: { kind: 'hs3', colors: ['#75AADB', '#FFFFFF', '#75AADB'] } },
  AUS: { name: 'Australia',     abbr: 'AUS', league: 'intl', primary: '#00843D', secondary: '#FFCD00', flag: { kind: 'canton', base: '#012169', canton: '#FFFFFF' } },
  AUT: { name: 'Austria',       abbr: 'AUT', league: 'intl', primary: '#ED2939', secondary: '#FFFFFF', flag: { kind: 'hs3', colors: ['#ED2939', '#FFFFFF', '#ED2939'] } },
  BEL: { name: 'Belgium',       abbr: 'BEL', league: 'intl', primary: '#FDDA24', secondary: '#000000', flag: { kind: 'vs3', colors: ['#000000', '#FDDA24', '#EF3340'] } },
  BOL: { name: 'Bolivia',       abbr: 'BOL', league: 'intl', primary: '#007934', secondary: '#FFD100', flag: { kind: 'hs3', colors: ['#D52B1E', '#FFD100', '#007934'] } },
  BRA: { name: 'Brazil',        abbr: 'BRA', league: 'intl', primary: '#009C3B', secondary: '#FFDF00', flag: { kind: 'solid', color: '#009C3B' } },
  BUL: { name: 'Bulgaria',      abbr: 'BUL', league: 'intl', primary: '#00966E', secondary: '#D62612', flag: { kind: 'hs3', colors: ['#FFFFFF', '#00966E', '#D62612'] } },
  CAN: { name: 'Canada',        abbr: 'CAN', league: 'intl', primary: '#FF0000', secondary: '#FFFFFF', flag: { kind: 'vs3', colors: ['#FF0000', '#FFFFFF', '#FF0000'] } },
  CHI: { name: 'Chile',         abbr: 'CHI', league: 'intl', primary: '#D52B1E', secondary: '#0033A0', flag: { kind: 'vs2', colors: ['#FFFFFF', '#D52B1E'] } },
  CIV: { name: 'Ivory Coast',   abbr: 'CIV', league: 'intl', primary: '#009E60', secondary: '#F77F00', flag: { kind: 'vs3', colors: ['#F77F00', '#FFFFFF', '#009E60'] } },
  CMR: { name: 'Cameroon',      abbr: 'CMR', league: 'intl', primary: '#007A5E', secondary: '#CE1126', flag: { kind: 'vs3', colors: ['#007A5E', '#CE1126', '#FCD116'] } },
  COL: { name: 'Colombia',      abbr: 'COL', league: 'intl', primary: '#FFCD00', secondary: '#003893', flag: { kind: 'hs3', colors: ['#FFCD00', '#003893', '#CE1126'] } },
  CRC: { name: 'Costa Rica',    abbr: 'CRC', league: 'intl', primary: '#002B7F', secondary: '#CE1126', flag: { kind: 'hs3', colors: ['#002B7F', '#FFFFFF', '#CE1126'] } },
  CRO: { name: 'Croatia',       abbr: 'CRO', league: 'intl', primary: '#FF0000', secondary: '#171796', flag: { kind: 'hs3', colors: ['#FF0000', '#FFFFFF', '#171796'] } },
  CZE: { name: 'Czech Republic',abbr: 'CZE', league: 'intl', primary: '#11457E', secondary: '#D7141A', flag: { kind: 'hs2', colors: ['#FFFFFF', '#D7141A'] } },
  DEN: { name: 'Denmark',       abbr: 'DEN', league: 'intl', primary: '#C8102E', secondary: '#FFFFFF', flag: { kind: 'nordic', bg: '#C8102E', cross: '#FFFFFF' } },
  ECU: { name: 'Ecuador',       abbr: 'ECU', league: 'intl', primary: '#FFD100', secondary: '#0033A0', flag: { kind: 'hs3', colors: ['#FFD100', '#0033A0', '#EF3340'] } },
  EGY: { name: 'Egypt',         abbr: 'EGY', league: 'intl', primary: '#CE1126', secondary: '#000000', flag: { kind: 'hs3', colors: ['#CE1126', '#FFFFFF', '#000000'] } },
  ENG: { name: 'England',       abbr: 'ENG', league: 'intl', primary: '#CE1124', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#FFFFFF' } },
  ESP: { name: 'Spain',         abbr: 'ESP', league: 'intl', primary: '#AA151B', secondary: '#F1BF00', flag: { kind: 'hs3', colors: ['#AA151B', '#F1BF00', '#AA151B'] } },
  FIN: { name: 'Finland',       abbr: 'FIN', league: 'intl', primary: '#003580', secondary: '#FFFFFF', flag: { kind: 'nordic', bg: '#FFFFFF', cross: '#003580' } },
  FRA: { name: 'France',        abbr: 'FRA', league: 'intl', primary: '#0055A4', secondary: '#EF4135', flag: { kind: 'vs3', colors: ['#0055A4', '#FFFFFF', '#EF4135'] } },
  GER: { name: 'Germany',       abbr: 'GER', league: 'intl', primary: '#000000', secondary: '#FFCE00', flag: { kind: 'hs3', colors: ['#000000', '#DD0000', '#FFCE00'] } },
  GHA: { name: 'Ghana',         abbr: 'GHA', league: 'intl', primary: '#006B3F', secondary: '#FCD116', flag: { kind: 'hs3', colors: ['#CE1126', '#FCD116', '#006B3F'] } },
  GRE: { name: 'Greece',        abbr: 'GRE', league: 'intl', primary: '#0D5EAF', secondary: '#FFFFFF', flag: { kind: 'canton', base: '#0D5EAF', canton: '#FFFFFF' } },
  HUN: { name: 'Hungary',       abbr: 'HUN', league: 'intl', primary: '#CE2939', secondary: '#477050', flag: { kind: 'hs3', colors: ['#CE2939', '#FFFFFF', '#477050'] } },
  IRL: { name: 'Ireland',       abbr: 'IRL', league: 'intl', primary: '#169B62', secondary: '#FF883E', flag: { kind: 'vs3', colors: ['#169B62', '#FFFFFF', '#FF883E'] } },
  IRN: { name: 'Iran',          abbr: 'IRN', league: 'intl', primary: '#239F40', secondary: '#DA0000', flag: { kind: 'hs3', colors: ['#239F40', '#FFFFFF', '#DA0000'] } },
  ISL: { name: 'Iceland',       abbr: 'ISL', league: 'intl', primary: '#02529C', secondary: '#DC1E35', flag: { kind: 'nordic', bg: '#02529C', cross: '#DC1E35' } },
  ITA: { name: 'Italy',         abbr: 'ITA', league: 'intl', primary: '#008C45', secondary: '#CD212A', flag: { kind: 'vs3', colors: ['#008C45', '#F4F5F0', '#CD212A'] } },
  JPN: { name: 'Japan',         abbr: 'JPN', league: 'intl', primary: '#BC002D', secondary: '#FFFFFF', flag: { kind: 'disc', bg: '#FFFFFF', disc: '#BC002D' } },
  KOR: { name: 'South Korea',   abbr: 'KOR', league: 'intl', primary: '#003478', secondary: '#C60C30', flag: { kind: 'disc', bg: '#FFFFFF', disc: '#C60C30' } },
  KSA: { name: 'Saudi Arabia',  abbr: 'KSA', league: 'intl', primary: '#006C35', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#006C35' } },
  MAR: { name: 'Morocco',       abbr: 'MAR', league: 'intl', primary: '#C1272D', secondary: '#006233', flag: { kind: 'solid', color: '#C1272D' } },
  MEX: { name: 'Mexico',        abbr: 'MEX', league: 'intl', primary: '#006847', secondary: '#CE1126', flag: { kind: 'vs3', colors: ['#006847', '#FFFFFF', '#CE1126'] } },
  NED: { name: 'Netherlands',   abbr: 'NED', league: 'intl', primary: '#FF4F00', secondary: '#21468B', flag: { kind: 'hs3', colors: ['#AE1C28', '#FFFFFF', '#21468B'] } },
  NGA: { name: 'Nigeria',       abbr: 'NGA', league: 'intl', primary: '#008751', secondary: '#FFFFFF', flag: { kind: 'vs3', colors: ['#008751', '#FFFFFF', '#008751'] } },
  NOR: { name: 'Norway',        abbr: 'NOR', league: 'intl', primary: '#EF2B2D', secondary: '#002868', flag: { kind: 'nordic', bg: '#EF2B2D', cross: '#002868' } },
  PAR: { name: 'Paraguay',      abbr: 'PAR', league: 'intl', primary: '#D52B1E', secondary: '#0038A8', flag: { kind: 'hs3', colors: ['#D52B1E', '#FFFFFF', '#0038A8'] } },
  PER: { name: 'Peru',          abbr: 'PER', league: 'intl', primary: '#D91023', secondary: '#FFFFFF', flag: { kind: 'vs3', colors: ['#D91023', '#FFFFFF', '#D91023'] } },
  POL: { name: 'Poland',        abbr: 'POL', league: 'intl', primary: '#DC143C', secondary: '#FFFFFF', flag: { kind: 'hs2', colors: ['#FFFFFF', '#DC143C'] } },
  POR: { name: 'Portugal',      abbr: 'POR', league: 'intl', primary: '#006600', secondary: '#FF0000', flag: { kind: 'vs2', colors: ['#006600', '#FF0000'] } },
  QAT: { name: 'Qatar',         abbr: 'QAT', league: 'intl', primary: '#8D1B3D', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#8D1B3D' } },
  ROU: { name: 'Romania',       abbr: 'ROU', league: 'intl', primary: '#002B7F', secondary: '#FCD116', flag: { kind: 'vs3', colors: ['#002B7F', '#FCD116', '#CE1126'] } },
  RUS: { name: 'Russia',        abbr: 'RUS', league: 'intl', primary: '#0039A6', secondary: '#D52B1E', flag: { kind: 'hs3', colors: ['#FFFFFF', '#0039A6', '#D52B1E'] } },
  SCO: { name: 'Scotland',      abbr: 'SCO', league: 'intl', primary: '#0065BD', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#0065BD' } },
  SEN: { name: 'Senegal',       abbr: 'SEN', league: 'intl', primary: '#00853F', secondary: '#FDEF42', flag: { kind: 'vs3', colors: ['#00853F', '#FDEF42', '#E31B23'] } },
  SRB: { name: 'Serbia',        abbr: 'SRB', league: 'intl', primary: '#0C4076', secondary: '#C6363C', flag: { kind: 'hs3', colors: ['#C6363C', '#0C4076', '#FFFFFF'] } },
  SUI: { name: 'Switzerland',   abbr: 'SUI', league: 'intl', primary: '#DA291C', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#DA291C' } },
  SVK: { name: 'Slovakia',      abbr: 'SVK', league: 'intl', primary: '#0B4EA2', secondary: '#EE1C25', flag: { kind: 'hs3', colors: ['#FFFFFF', '#0B4EA2', '#EE1C25'] } },
  SWE: { name: 'Sweden',        abbr: 'SWE', league: 'intl', primary: '#006AA7', secondary: '#FECC00', flag: { kind: 'nordic', bg: '#006AA7', cross: '#FECC00' } },
  TUN: { name: 'Tunisia',       abbr: 'TUN', league: 'intl', primary: '#E70013', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#E70013' } },
  TUR: { name: 'Turkey',        abbr: 'TUR', league: 'intl', primary: '#E30A17', secondary: '#FFFFFF', flag: { kind: 'solid', color: '#E30A17' } },
  UKR: { name: 'Ukraine',       abbr: 'UKR', league: 'intl', primary: '#0057B7', secondary: '#FFD700', flag: { kind: 'hs2', colors: ['#0057B7', '#FFD700'] } },
  URU: { name: 'Uruguay',       abbr: 'URU', league: 'intl', primary: '#0038A8', secondary: '#FCD116', flag: { kind: 'canton', base: '#FFFFFF', canton: '#FCD116' } },
  USA: { name: 'United States', abbr: 'USA', league: 'intl', primary: '#B22234', secondary: '#3C3B6E', flag: { kind: 'canton', base: '#B22234', canton: '#3C3B6E' } },
  VEN: { name: 'Venezuela',     abbr: 'VEN', league: 'intl', primary: '#0033A0', secondary: '#FFD100', flag: { kind: 'hs3', colors: ['#FFD100', '#0033A0', '#CF142B'] } },
  WAL: { name: 'Wales',         abbr: 'WAL', league: 'intl', primary: '#C8102E', secondary: '#FFFFFF', flag: { kind: 'hs2', colors: ['#FFFFFF', '#009E49'] } },

  // ═══════════════════════════════ MLS ═══════════════════════════════
  'MLS-ATL': { name: 'Atlanta United',     abbr: 'ATL',  league: 'mls', primary: '#80000B', secondary: '#B8A369' },
  'MLS-AUS': { name: 'Austin FC',          abbr: 'AUS',  league: 'mls', primary: '#00B140', secondary: '#000000' },
  'MLS-CLT': { name: 'Charlotte FC',       abbr: 'CLT',  league: 'mls', primary: '#1A85C8', secondary: '#000000' },
  'MLS-CHI': { name: 'Chicago Fire',       abbr: 'CHI',  league: 'mls', primary: '#A8203A', secondary: '#091F40' },
  'MLS-CIN': { name: 'FC Cincinnati',      abbr: 'CIN',  league: 'mls', primary: '#FE5000', secondary: '#003087' },
  'MLS-COL': { name: 'Colorado Rapids',    abbr: 'COL',  league: 'mls', primary: '#960A2C', secondary: '#0F2F57' },
  'MLS-CLB': { name: 'Columbus Crew',      abbr: 'CLB',  league: 'mls', primary: '#FEDD00', secondary: '#000000' },
  'MLS-DAL': { name: 'FC Dallas',          abbr: 'DAL',  league: 'mls', primary: '#B5282E', secondary: '#1A356E' },
  'MLS-DC':  { name: 'D.C. United',        abbr: 'DC',   league: 'mls', primary: '#000000', secondary: '#EF3E42' },
  'MLS-HOU': { name: 'Houston Dynamo',     abbr: 'HOU',  league: 'mls', primary: '#F36600', secondary: '#101820' },
  'MLS-MIA': { name: 'Inter Miami CF',     abbr: 'MIA',  league: 'mls', primary: '#F7B5CD', secondary: '#231F20' },
  'MLS-LA':  { name: 'LA Galaxy',          abbr: 'LAG',  league: 'mls', primary: '#00245D', secondary: '#F4B204' },
  'MLS-LAFC':{ name: 'Los Angeles FC',     abbr: 'LAFC', league: 'mls', primary: '#000000', secondary: '#C39E6D' },
  'MLS-MIN': { name: 'Minnesota United',   abbr: 'MIN',  league: 'mls', primary: '#8CD2F4', secondary: '#585958' },
  'MLS-MTL': { name: 'CF Montréal',        abbr: 'MTL',  league: 'mls', primary: '#0033A0', secondary: '#000000' },
  'MLS-NSH': { name: 'Nashville SC',       abbr: 'NSH',  league: 'mls', primary: '#F6EB61', secondary: '#1C2F4A' },
  'MLS-NE':  { name: 'New England Revolution', abbr: 'NE', league: 'mls', primary: '#0A2240', secondary: '#D6001C' },
  'MLS-NYC': { name: 'New York City FC',   abbr: 'NYC',  league: 'mls', primary: '#4CAEE3', secondary: '#0F2D52' },
  'MLS-NYRB':{ name: 'New York Red Bulls', abbr: 'RBNY', league: 'mls', primary: '#BA0C2F', secondary: '#002F6C' },
  'MLS-ORL': { name: 'Orlando City',       abbr: 'ORL',  league: 'mls', primary: '#633492', secondary: '#FDE192' },
  'MLS-PHI': { name: 'Philadelphia Union', abbr: 'PHI',  league: 'mls', primary: '#002A5C', secondary: '#B18500' },
  'MLS-POR': { name: 'Portland Timbers',   abbr: 'POR',  league: 'mls', primary: '#004812', secondary: '#ECD19E' },
  'MLS-RSL': { name: 'Real Salt Lake',     abbr: 'RSL',  league: 'mls', primary: '#9F1B31', secondary: '#0D2240' },
  'MLS-SD':  { name: 'San Diego FC',       abbr: 'SD',   league: 'mls', primary: '#006699', secondary: '#FFFFFF' },
  'MLS-SJ':  { name: 'San Jose Earthquakes', abbr: 'SJ', league: 'mls', primary: '#0050A0', secondary: '#000000' },
  'MLS-SEA': { name: 'Seattle Sounders',   abbr: 'SEA',  league: 'mls', primary: '#5D9741', secondary: '#236192' },
  'MLS-SKC': { name: 'Sporting Kansas City',abbr: 'SKC', league: 'mls', primary: '#91B0D5', secondary: '#002F65' },
  'MLS-STL': { name: 'St. Louis City SC',  abbr: 'STL',  league: 'mls', primary: '#E31937', secondary: '#001E62' },
  'MLS-TOR': { name: 'Toronto FC',         abbr: 'TOR',  league: 'mls', primary: '#B81137', secondary: '#B5A569' },
  'MLS-VAN': { name: 'Vancouver Whitecaps',abbr: 'VAN',  league: 'mls', primary: '#012F6B', secondary: '#97D4E9' },

  // ═══════════════════════════════ MLB ═══════════════════════════════
  'MLB-ARI': { name: 'Arizona Diamondbacks', abbr: 'ARI', league: 'mlb', primary: '#A71930', secondary: '#E3D4AD' },
  'MLB-ATL': { name: 'Atlanta Braves',       abbr: 'ATL', league: 'mlb', primary: '#CE1141', secondary: '#13274F' },
  'MLB-BAL': { name: 'Baltimore Orioles',    abbr: 'BAL', league: 'mlb', primary: '#DF4601', secondary: '#000000' },
  'MLB-BOS': { name: 'Boston Red Sox',       abbr: 'BOS', league: 'mlb', primary: '#BD3039', secondary: '#0C2340' },
  'MLB-CHC': { name: 'Chicago Cubs',         abbr: 'CHC', league: 'mlb', primary: '#0E3386', secondary: '#CC3433' },
  'MLB-CWS': { name: 'Chicago White Sox',    abbr: 'CWS', league: 'mlb', primary: '#000000', secondary: '#C4CED4' },
  'MLB-CIN': { name: 'Cincinnati Reds',      abbr: 'CIN', league: 'mlb', primary: '#C6011F', secondary: '#000000' },
  'MLB-CLE': { name: 'Cleveland Guardians',  abbr: 'CLE', league: 'mlb', primary: '#0C2340', secondary: '#E31937' },
  'MLB-COL': { name: 'Colorado Rockies',     abbr: 'COL', league: 'mlb', primary: '#333366', secondary: '#C4CED4' },
  'MLB-DET': { name: 'Detroit Tigers',       abbr: 'DET', league: 'mlb', primary: '#0C2C56', secondary: '#FA4616' },
  'MLB-HOU': { name: 'Houston Astros',       abbr: 'HOU', league: 'mlb', primary: '#002D62', secondary: '#EB6E1F' },
  'MLB-KC':  { name: 'Kansas City Royals',   abbr: 'KC',  league: 'mlb', primary: '#004687', secondary: '#BD9B60' },
  'MLB-LAA': { name: 'Los Angeles Angels',   abbr: 'LAA', league: 'mlb', primary: '#BA0021', secondary: '#003263' },
  'MLB-LAD': { name: 'Los Angeles Dodgers',  abbr: 'LAD', league: 'mlb', primary: '#005A9C', secondary: '#FFFFFF' },
  'MLB-MIA': { name: 'Miami Marlins',        abbr: 'MIA', league: 'mlb', primary: '#00A3E0', secondary: '#EF3340' },
  'MLB-MIL': { name: 'Milwaukee Brewers',    abbr: 'MIL', league: 'mlb', primary: '#12284B', secondary: '#FFC52F' },
  'MLB-MIN': { name: 'Minnesota Twins',      abbr: 'MIN', league: 'mlb', primary: '#002B5C', secondary: '#D31145' },
  'MLB-NYM': { name: 'New York Mets',        abbr: 'NYM', league: 'mlb', primary: '#002D72', secondary: '#FF5910' },
  'MLB-NYY': { name: 'New York Yankees',     abbr: 'NYY', league: 'mlb', primary: '#0C2340', secondary: '#FFFFFF' },
  'MLB-OAK': { name: 'Oakland Athletics',    abbr: 'OAK', league: 'mlb', primary: '#003831', secondary: '#EFB21E' },
  'MLB-PHI': { name: 'Philadelphia Phillies',abbr: 'PHI', league: 'mlb', primary: '#E81828', secondary: '#002D72' },
  'MLB-PIT': { name: 'Pittsburgh Pirates',   abbr: 'PIT', league: 'mlb', primary: '#27251F', secondary: '#FDB827' },
  'MLB-SD':  { name: 'San Diego Padres',     abbr: 'SD',  league: 'mlb', primary: '#2F241D', secondary: '#FFC425' },
  'MLB-SF':  { name: 'San Francisco Giants', abbr: 'SF',  league: 'mlb', primary: '#FD5A1E', secondary: '#27251F' },
  'MLB-SEA': { name: 'Seattle Mariners',     abbr: 'SEA', league: 'mlb', primary: '#0C2C56', secondary: '#005C5C' },
  'MLB-STL': { name: 'St. Louis Cardinals',  abbr: 'STL', league: 'mlb', primary: '#C41E3A', secondary: '#0C2340' },
  'MLB-TB':  { name: 'Tampa Bay Rays',       abbr: 'TB',  league: 'mlb', primary: '#092C5C', secondary: '#8FBCE6' },
  'MLB-TEX': { name: 'Texas Rangers',        abbr: 'TEX', league: 'mlb', primary: '#003278', secondary: '#C0111F' },
  'MLB-TOR': { name: 'Toronto Blue Jays',    abbr: 'TOR', league: 'mlb', primary: '#134A8E', secondary: '#1D2D5C' },
  'MLB-WSH': { name: 'Washington Nationals', abbr: 'WSH', league: 'mlb', primary: '#AB0003', secondary: '#14225A' },

  // ═══════════════════════════════ EUROPEAN CLUBS ═══════════════════════════════
  'EUR-RMA': { name: 'Real Madrid',          abbr: 'RMA', league: 'eur', primary: '#FEBE10', secondary: '#00529F' },
  'EUR-BAR': { name: 'FC Barcelona',         abbr: 'BAR', league: 'eur', primary: '#004D98', secondary: '#A50044' },
  'EUR-ATM': { name: 'Atlético Madrid',      abbr: 'ATM', league: 'eur', primary: '#CB3524', secondary: '#272E61' },
  'EUR-MUN': { name: 'Manchester United',    abbr: 'MUN', league: 'eur', primary: '#DA291C', secondary: '#FBE122' },
  'EUR-MCI': { name: 'Manchester City',      abbr: 'MCI', league: 'eur', primary: '#6CABDD', secondary: '#1C2C5B' },
  'EUR-LIV': { name: 'Liverpool',            abbr: 'LIV', league: 'eur', primary: '#C8102E', secondary: '#00B2A9' },
  'EUR-ARS': { name: 'Arsenal',              abbr: 'ARS', league: 'eur', primary: '#EF0107', secondary: '#023474' },
  'EUR-CHE': { name: 'Chelsea',              abbr: 'CHE', league: 'eur', primary: '#034694', secondary: '#DBA111' },
  'EUR-TOT': { name: 'Tottenham Hotspur',    abbr: 'TOT', league: 'eur', primary: '#132257', secondary: '#FFFFFF' },
  'EUR-BAY': { name: 'Bayern Munich',        abbr: 'BAY', league: 'eur', primary: '#DC052D', secondary: '#0066B2' },
  'EUR-DOR': { name: 'Borussia Dortmund',    abbr: 'BVB', league: 'eur', primary: '#FDE100', secondary: '#000000' },
  'EUR-JUV': { name: 'Juventus',             abbr: 'JUV', league: 'eur', primary: '#000000', secondary: '#FFFFFF' },
  'EUR-MIL': { name: 'AC Milan',             abbr: 'MIL', league: 'eur', primary: '#FB090B', secondary: '#000000' },
  'EUR-INT': { name: 'Inter Milan',          abbr: 'INT', league: 'eur', primary: '#010E80', secondary: '#000000' },
  'EUR-PSG': { name: 'Paris Saint-Germain',  abbr: 'PSG', league: 'eur', primary: '#004170', secondary: '#DA291C' },
  'EUR-AJX': { name: 'Ajax',                 abbr: 'AJX', league: 'eur', primary: '#D2122E', secondary: '#FFFFFF' },
  'EUR-PTO': { name: 'FC Porto',             abbr: 'POR', league: 'eur', primary: '#00428B', secondary: '#FFFFFF' },
  'EUR-BEN': { name: 'Benfica',              abbr: 'BEN', league: 'eur', primary: '#E8002E', secondary: '#FFFFFF' },
});

const FALLBACK: TeamBrand = {
  id: '_UNKNOWN',
  name: 'Unknown',
  abbr: '—',
  league: 'intl',
  primary: '#737373',
  secondary: '#FAFAFA',
};

export function getTeam(id: string): TeamBrand {
  return (TEAMS as Record<string, TeamBrand>)[id] ?? FALLBACK;
}

// True if the team's primary color is light enough that dark text reads better.
export function isLightPrimary(team: TeamBrand): boolean {
  const hex = team.primary.replace('#', '');
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  // Rec. 709 luminance
  const y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return y > 170;
}
