import { CactusClient, DEFAULT_MODEL } from './client';
import type { CactusLMMessage } from 'cactus-react-native';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from './prompts';
import * as functions from './functions';
import type { MatchContext } from './functions';
import type { WidgetSpec } from './state/eventBus';
import type { PrecedentPattern } from './schema';
import { getMatchCache } from './state/matchCache';

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

export async function askGemma(
  input: AskGemmaInput,
  context: AskGemmaContext,
  routing: AskGemmaRouting,
): Promise<AskGemmaResult> {
  const t0 = Date.now();
  await client.ensureLoaded(DEFAULT_MODEL);

  const hint = routing === 'cloud' ? 'CLOUD' : 'LOCAL';
  const userContent = [
    `ROUTING=${hint}`,
    `MODE=${context.mode}`,
    `MATCH_STATE=${JSON.stringify(context.match_state)}`,
    `RECENT_TRANSCRIPT=${context.recent_transcripts.slice(-3).join(' | ')}`,
    input.prompt ? `QUESTION=${input.prompt}` : 'Transcribe and answer the press-to-talk audio.',
  ].join('\n');

  const messages: CactusLMMessage[] = [
    { role: 'system', content: QUERY_OR_COMMAND_PROMPT },
    { role: 'user',   content: userContent },
  ];

  const audioPcm = input.audio ? arrayBufferToPcm(input.audio) : undefined;
  const out = await client.complete({ messages, audio: audioPcm });

  const parsed = safeJson(out.response);
  const latency_ms = Date.now() - t0;

  if (!parsed || parsed.trust_escape || parsed.intent === 'ungrounded') {
    return {
      stat_text: "I don't have verified data on that.",
      source: 'trust_escape',
      confidence_high: false,
      transcript: parsed?.transcript,
      latency_ms,
    };
  }

  let precedent: PrecedentPattern | undefined;
  if (parsed.precedent_id) {
    try {
      precedent = getMatchCache().precedent_index.find((p) => p.id === parsed.precedent_id);
    } catch {
      precedent = undefined;
    }
  }

  return {
    stat_text: String(parsed.answer ?? parsed.stat_text ?? ''),
    source: String(parsed.source ?? 'Sportradar'),
    confidence_high: Boolean(parsed.confidence_high),
    player_id: parsed.player_id ?? undefined,
    transcript: parsed.transcript,
    widget_spec: parsed.widget_spec ?? undefined,
    precedent,
    counter_narrative: parsed.counter_narrative ?? undefined,
    latency_ms,
  };
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}

function arrayBufferToPcm(buf: ArrayBuffer): number[] {
  const view = new Int16Array(buf);
  const out = new Array(view.length);
  for (let i = 0; i < view.length; i++) out[i] = view[i];
  return out;
}

export const __internal__ = { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT, client };
