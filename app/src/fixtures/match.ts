import { MatchEvent, MomentumTag, StoryItem } from '../feature2/LivePanels';
import { WidgetRow } from '../feature2/VoiceWidget';
import { tokens } from '../theme/tokens';

// Pre-seeded storylines for the Argentina vs France 2022 WC Final.
// STT would auto-tick these as the commentator mentions them.
export const INITIAL_STORIES: StoryItem[] = [
  { id: 's1', text: 'Messi 5th & final World Cup — "last dance"',                       state: 'pending' },
  { id: 's2', text: 'Mbappé chasing Golden Boot + back-to-back WC',                     state: 'pending' },
  { id: 's3', text: 'Peter Drury calls — prepare for poetic moments',                   state: 'pending' },
  { id: 's4', text: '2018 final: France 4-2 Croatia (Mbappé scored)',                   state: 'pending' },
  { id: 's5', text: 'Rabiot flu watch — Fofana warmup',                                  state: 'pending' },
  { id: 's6', text: 'Emi Martínez has 1 shootout win already (NL 2021)',                state: 'pending' },
  { id: 's7', text: 'Giroud passed Henry in R16 — France all-time scoring record',      state: 'pending' },
  { id: 's8', text: 'Messi scored in every knockout round · keep that streak alive',    state: 'pending' },
];

// The match beats — what would fire through the Zustand event bus during the
// live game. Sequence indexed so we can simulate over a short demo timeline.
export type MatchBeat = {
  at: number;           // seconds offset from demo start (10x compressed)
  kind: 'goal' | 'shot' | 'var' | 'card' | 'sub' | 'ht' | 'ft' | 'et_start' | 'penalties';
  minute: string;
  label: string;
  score?: { arg: number; fra: number };
  color?: string;
  storyTickId?: string;   // auto-tick this storyline when the beat fires
  momentum?: MomentumTag;
  card?: {
    stat: {
      player: string;
      playerSub: string;
      minute: string;
      type: string;
      scoreChange: string;
      heroNumeral: string;
      heroCaption: string;
      context: string[];
      latency?: string;
    };
    precedent: { headline: string; support?: string };
    counter: { forSide: string; headline: string; support?: string };
  };
};

// Compressed 6-second demo timeline that walks through four defining beats.
// "Minute" in the match · "at" is elapsed demo seconds.
export const MATCH_BEATS: MatchBeat[] = [
  {
    at: 2,
    kind: 'goal',
    minute: "23'",
    label: "⚽ MESSI (PEN) — ARG",
    score: { arg: 1, fra: 0 },
    color: tokens.text,
    storyTickId: 's8',
    momentum: { label: 'ARG DOMINANT', color: tokens.text },
    card: {
      stat: {
        player: 'LIONEL MESSI',
        playerSub: '#10 · FW · ARG',
        minute: "23'",
        type: 'PEN',
        scoreChange: '1-0 ARG',
        heroNumeral: '6',
        heroCaption: 'th goal of this tournament — leads Argentina by 3',
        context: [
          '2nd WC Final goal of his career (after 2014)',
          '1st player to score in every WC knockout round',
          '98% conversion from the spot in WC knockouts since 2014',
        ],
        latency: '842ms',
      },
      precedent: {
        headline: 'Teams scoring first in WC Finals have won 12 of 14 since 1970.',
        support: 'Only exceptions: 1994 BRA vs ITA (pens), 2006 ITA vs FRA (pens).',
      },
      counter: {
        forSide: 'FRA',
        headline: 'France came back from 1-0 down to win the 2018 Final vs Croatia.',
        support: 'Mbappé scored that day. Same dressing room, same 10 on the jersey.',
      },
    },
  },
  {
    at: 5,
    kind: 'goal',
    minute: "36'",
    label: '⚽ DI MARÍA — ARG',
    score: { arg: 2, fra: 0 },
    color: tokens.text,
    storyTickId: 's1',
    momentum: { label: 'FRA RATTLED', color: tokens.esoteric },
    card: {
      stat: {
        player: 'ÁNGEL DI MARÍA',
        playerSub: '#11 · MF · ARG · age 34',
        minute: "36'",
        type: 'OPEN PLAY',
        scoreChange: '2-0 ARG',
        heroNumeral: '2',
        heroCaption: 'nd career WC goal — first since 2014 Final',
        context: [
          'Back from calf injury — started over Acuña tonight',
          '2021 Copa América final scorer vs Brazil',
          "Messi's assist — 3rd of the tournament",
        ],
        latency: '891ms',
      },
      precedent: {
        headline: 'Teams leading 2-0 in WC Finals have won 19 of 22 since 1970.',
        support: '86% conversion. Remaining 3: 1966 ENG, 1994 ITA, 1966 comeback.',
      },
      counter: {
        forSide: 'FRA',
        headline: 'BUT: 1966 WG vs ENG came back from 0-2 · 1994 BRA 0-2 ITA recovered.',
        support: 'Both recoveries went to extra time or penalties.',
      },
    },
  },
  {
    at: 8,
    kind: 'goal',
    minute: "80'",
    label: '⚽ MBAPPÉ (PEN) — FRA',
    score: { arg: 2, fra: 1 },
    color: tokens.live,
    storyTickId: 's2',
    momentum: { label: 'FRA SURGING', color: tokens.live },
    card: {
      stat: {
        player: 'KYLIAN MBAPPÉ',
        playerSub: '#10 · FW · FRA · age 23',
        minute: "80'",
        type: 'PEN',
        scoreChange: '2-1 ARG',
        heroNumeral: '6',
        heroCaption: 'th goal of this tournament — ties Messi for Golden Boot',
        context: [
          'Youngest player to reach 10 WC goals since Pelé',
          '2nd Mbappé goal in a WC Final (2018 + 2022)',
          'France have NEVER lost a WC match when Mbappé scores',
        ],
        latency: '812ms',
      },
      precedent: {
        headline: 'French comebacks from 2-0 down in knockout WC games: 2 of last 4.',
        support: '2006 SF vs POR (1-0 actually), 1984 Euro, 1998 R16. Pattern exists.',
      },
      counter: {
        forSide: 'ARG',
        headline: "Emi Martínez has kept 4 clean sheets this WC — still has a shootout in the bank.",
        support: 'NL 2021 trophy came down to him saving Suárez in pens.',
      },
    },
  },
  {
    at: 11,
    kind: 'goal',
    minute: "81'",
    label: '⚽ MBAPPÉ — FRA (97s brace)',
    score: { arg: 2, fra: 2 },
    color: tokens.live,
    momentum: { label: 'FRA RUN: 2 IN 97s', color: tokens.live },
    card: {
      stat: {
        player: 'KYLIAN MBAPPÉ',
        playerSub: '#10 · FW · FRA · brace',
        minute: "81'",
        type: 'OPEN PLAY',
        scoreChange: '2-2',
        heroNumeral: '97',
        heroCaption: 'seconds between Mbappé goals — fastest WC Final brace ever',
        context: [
          'Previous record: Zidane, 1998 — 27 mins between',
          'Mbappé WC career goals: 9 · passes Messi',
          'All four goals scored in this match via shots inside the box',
        ],
        latency: '798ms',
      },
      precedent: {
        headline: '2-2 at 81\' in WC Finals → extra time every time (1970, 1994, 2006).',
        support: 'None resolved in regulation. Mental prep: 30+ more minutes.',
      },
      counter: {
        forSide: 'ARG',
        headline: 'Scaloni still has Lautaro, Paredes, Pezzella on the bench.',
        support: 'France used both Giroud and Dembélé subs. No attacking options left.',
      },
    },
  },
];
