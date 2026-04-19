import { CactusClient } from './client';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from './prompts';
import * as functions from './functions';
import type { MatchContext } from './functions';
import type { WidgetSpec } from './state/eventBus';
import type { PrecedentPattern } from './schema';

const MODEL_ID = 'google/functiongemma-270m-it';

const client = new CactusClient();

export type AskGemmaInput   = { prompt?: string; audio?: ArrayBuffer };
export type AskGemmaContext = {
  mode: 'stats_first' | 'story_first' | 'tactical' | 'custom';
  match_state: MatchContext;
  recent_transcripts: string[];
  commentator_profile: ReturnType<typeof functions.get_commentator_profile>;
};
export type AskGemmaRouting = 'auto' | 'local' | 'cloud';

export type AskGemmaResult = {
  stat_text: string;
  source: string;
  confidence_high: boolean;
  player_id?: string;
  latency_ms: number;
  transcript?: string;
  widget_spec?: WidgetSpec;
  precedent?: PrecedentPattern;
  counter_narrative?: { text: string; for_team: 'home' | 'away' };
};

const TOOLS = {
  get_player_stat: functions.get_player_stat,
  get_team_stat: functions.get_team_stat,
  get_match_context: functions.get_match_context,
  get_historical: functions.get_historical,
  get_commentator_profile: functions.get_commentator_profile,
};

export async function askGemma(
  input: AskGemmaInput,
  context: AskGemmaContext,
  routing: AskGemmaRouting,
): Promise<AskGemmaResult> {
  const t0 = Date.now();
  await client.ensureLoaded(MODEL_ID);

  const hint = routing === 'cloud' ? 'CLOUD' : 'LOCAL';
  const prompt = [
    QUERY_OR_COMMAND_PROMPT,
    `ROUTING=${hint}`,
    `MODE=${context.mode}`,
    `MATCH_STATE=${JSON.stringify(context.match_state)}`,
    `RECENT_TRANSCRIPT=${context.recent_transcripts.slice(-3).join(' | ')}`,
    input.prompt ? `QUESTION=${input.prompt}` : '',
  ].filter(Boolean).join('\n');

  const raw = await client.generate({ prompt, audio: input.audio, tools: TOOLS });

  const parsed = safeJson(raw);
  const latency_ms = Date.now() - t0;

  if (!parsed || parsed.trust_escape) {
    return {
      stat_text: "I don't have verified data on that.",
      source: 'trust_escape',
      confidence_high: false,
      transcript: parsed?.transcript,
      latency_ms,
    };
  }

  return {
    stat_text: String(parsed.answer ?? parsed.stat_text ?? ''),
    source: String(parsed.source ?? 'Sportradar'),
    confidence_high: Boolean(parsed.confidence_high),
    player_id: parsed.player_id ?? undefined,
    transcript: parsed.transcript,
    widget_spec: parsed.widget_spec ?? undefined,
    latency_ms,
  };
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}

// exported for orchestrator + smoke harness
export const __internal__ = { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT, client };
