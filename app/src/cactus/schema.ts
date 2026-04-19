import { z } from 'zod';

export const StatRecord = z.record(z.string(), z.union([z.number(), z.string()]));

export const PlayerSchema = z.object({
  id: z.string(),
  team_id: z.enum(['arg', 'fra']),
  shirt_number: z.number().int(),
  name: z.string(),
  position: z.enum(['GK', 'DF', 'MF', 'FW']),
  age: z.number().int(),
  club: z.string(),
  headshot_url: z.string().optional(),
  stats: z.object({
    tournament: StatRecord,
    career: StatRecord,
    form_last_5: StatRecord,
  }),
  role_tags: z.array(z.string()),
  storyline_ids: z.array(z.string()),
  h2h_notes: z.array(z.string()),
  didnt_know: z.array(z.string()),
  status: z.enum(['fit', 'doubtful', 'injured', 'suspended', 'not_in_squad']),
});

export const TeamSchema = z.object({
  id: z.enum(['arg', 'fra']),
  name: z.string(),
  flag_svg_path: z.string(),
  color_hex: z.string(),
  tournament_record: z.object({
    w: z.number(), d: z.number(), l: z.number(), gf: z.number(), ga: z.number(),
  }),
  h2h: z.object({
    all_time: z.object({ w: z.number(), d: z.number(), l: z.number() }),
    last_wc_meeting: z.string().optional(),
  }),
});

export const MatchSchema = z.object({
  id: z.string(),
  competition: z.string(),
  venue: z.string(),
  capacity: z.number(),
  kickoff_iso: z.string(),
  referee: z.object({ name: z.string(), federation: z.string(), tournament_yellows: z.number() }),
  weather: z.object({ temp_c: z.number(), condition: z.string() }),
});

export const StorylineSchema = z.object({
  id: z.string(),
  player_ids: z.array(z.string()),
  text: z.string(),
  category: z.enum(['last_dance', 'redemption', 'milestone', 'family', 'rivalry', 'tactical', 'record_watch']),
  priority_by_mode: z.object({
    stats_first: z.number(), story_first: z.number(), tactical: z.number(),
  }),
});

export const PrecedentPatternSchema = z.object({
  id: z.string(),
  trigger: z.object({
    event_type: z.enum([
      'goal', 'penalty', 'red_card', 'substitution', 'shot_on_target',
      'half_time', 'extra_time', 'penalty_shootout',
    ]),
    minute_range: z.tuple([z.number(), z.number()]).optional(),
    score_state: z.string().optional(),
    player_filters: z.object({
      age_lt: z.number().optional(),
      new_comer: z.boolean().optional(),
    }).optional(),
  }),
  stat_text: z.string(),
  counter_narrative: z.string().optional(),
  category: z.enum(['statistical', 'historical', 'tactical', 'emotional']),
  sources: z.array(z.string()),
});

export const MatchCacheSchema = z.object({
  match: MatchSchema,
  teams: z.object({ home: TeamSchema, away: TeamSchema }),
  players: z.array(PlayerSchema),
  storylines: z.array(StorylineSchema),
  precedent_index: z.array(PrecedentPatternSchema),
});

export type MatchCache = z.infer<typeof MatchCacheSchema>;
export type Player = z.infer<typeof PlayerSchema>;
export type Team = z.infer<typeof TeamSchema>;
export type PrecedentPattern = z.infer<typeof PrecedentPatternSchema>;
export type Storyline = z.infer<typeof StorylineSchema>;
