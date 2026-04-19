import { CactusClient, DEFAULT_MODEL, type FunctionCall } from '../client';
import type { CactusLMMessage, CactusLMTool } from 'cactus-react-native';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from '../prompts';
import * as functions from '../functions';
import { Gate } from './gate';
import { Dedupe } from './dedupe';
import { useEventBus, WidgetSpec } from '../state/eventBus';
import type { Chunk } from '../audio/continuous';
import { getMatchCache } from '../state/matchCache';

export const TOOLS: CactusLMTool[] = [
  {
    name: 'get_player_stat',
    description: 'Look up a player stat. Returns null if no match — never invent.',
    parameters: {
      type: 'object',
      properties: {
        player_name: { type: 'string', description: 'Player name (full or last) or shirt number' },
        situation:   { type: 'string', description: "Stat scope: 'current_tournament' | 'career' | 'form_last_5' | a metric hint" },
      },
      required: ['player_name'],
    },
  },
  {
    name: 'get_team_stat',
    description: 'Look up a team-level stat. Returns null if no match.',
    parameters: {
      type: 'object',
      properties: {
        team:   { type: 'string', description: "'arg' | 'fra' | 'home' | 'away'" },
        metric: { type: 'string', description: "Metric name, e.g. 'record'" },
      },
      required: ['team', 'metric'],
    },
  },
  {
    name: 'get_match_context',
    description: 'Returns the live match score, minute, phase, possession, shots.',
    parameters: {
      type: 'object',
      properties: { match_id: { type: 'string', description: 'Match identifier' } },
      required: ['match_id'],
    },
  },
  {
    name: 'get_historical',
    description: 'Find precedent patterns matching the current situation. Returns [] when no match.',
    parameters: {
      type: 'object',
      properties: { query: { type: 'string', description: 'Free-text query, e.g. "2-0 lead in WC Final"' } },
      required: ['query'],
    },
  },
];

const TOOL_IMPL: Record<string, (args: Record<string, unknown>) => unknown> = {
  get_player_stat: (a) => functions.get_player_stat(String(a.player_name ?? ''), String(a.situation ?? 'current_tournament')),
  get_team_stat:   (a) => functions.get_team_stat(a.team as 'arg' | 'fra' | 'home' | 'away', String(a.metric ?? '')),
  get_match_context: (a) => functions.get_match_context(String(a.match_id ?? '')),
  get_historical:  (a) => functions.get_historical(String(a.query ?? '')),
};

const MAX_TOOL_HOPS = 3;

function isAbort(err: unknown): boolean {
  return err instanceof Error && /abort/i.test(err.message);
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}

async function completeWithToolLoop(
  client: CactusClient,
  initialMessages: CactusLMMessage[],
  tools: CactusLMTool[],
  signal?: AbortSignal,
): Promise<{ response: string; functionCalls: FunctionCall[] }> {
  const messages = [...initialMessages];
  let lastResponse = '';
  let lastCalls: FunctionCall[] = [];
  for (let hop = 0; hop < MAX_TOOL_HOPS; hop++) {
    const out = await client.complete({ messages, tools, signal });
    lastResponse = out.response;
    lastCalls    = out.functionCalls;
    if (!out.functionCalls.length) return { response: out.response, functionCalls: [] };

    messages.push({ role: 'assistant', content: out.response });
    for (const call of out.functionCalls) {
      const impl = TOOL_IMPL[call.name];
      const result = impl ? safeRun(impl, call.arguments) : null;
      messages.push({ role: 'user', content: `TOOL_RESULT ${call.name}: ${JSON.stringify(result)}` });
    }
  }
  return { response: lastResponse, functionCalls: lastCalls };
}

function safeRun(impl: (a: Record<string, unknown>) => unknown, args: Record<string, unknown>): unknown {
  try { return impl(args); } catch { return null; }
}

export class Orchestrator {
  private client = new CactusClient();
  private gate   = new Gate();
  private dedupe = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
  private inflight: AbortController | null = null;

  async processAutonomousChunk(chunk: Chunk): Promise<void> {
    try {
      await this.processAutonomousChunkInner(chunk);
    } catch (err) {
      if (isAbort(err)) return;
      throw err;
    }
  }

  private async processAutonomousChunkInner(chunk: Chunk): Promise<void> {
    if (!this.gate.vadAccept(chunk.stats)) return;

    if (this.inflight) this.inflight.abort();
    const ac = new AbortController();
    this.inflight = ac;

    await this.client.ensureLoaded(DEFAULT_MODEL);

    const audioPcm = chunkToPcm(chunk.audio);

    const classify = await this.gate.classify(chunk.audio, async () => {
      const out = await this.client.complete({
        messages: [
          { role: 'system', content: AUTONOMOUS_PROMPT },
          { role: 'user',   content: 'Classify this audio chunk.' },
        ],
        audio: audioPcm,
        signal: ac.signal,
      });
      return safeJson(out.response);
    });

    if (classify.transcript) {
      useEventBus.getState().emit({
        type: 'transcript',
        text: classify.transcript,
        confidence: 0.9,
      });
    }

    if (!classify.stat_opportunity) return;

    const signature = {
      event_type: classify.event_type ?? 'other',
      players: (classify.players_mentioned ?? []).map((p) => p.toLowerCase()),
    };
    if (this.dedupe.shouldDrop({ signature, statText: classify.transcript, now: chunk.at })) return;
    if (classify.transcript) {
      this.dedupe.ingestTranscript(classify.transcript, chunk.at);
    }

    const ctx = functions.get_match_context('arg-vs-fra-2022-wc-final');
    const generateMessages: CactusLMMessage[] = [
      { role: 'system', content: GENERATE_PROMPT },
      { role: 'user',   content: [
        `EVENT_TYPE=${classify.event_type ?? 'unknown'}`,
        `PLAYERS=${(classify.players_mentioned ?? []).join(',')}`,
        `MATCH_STATE=${JSON.stringify({ score: ctx.score, minute: ctx.minute, phase: ctx.phase })}`,
        `TRANSCRIPT=${classify.transcript ?? ''}`,
      ].join('\n') },
    ];

    const finalOut = await completeWithToolLoop(this.client, generateMessages, TOOLS, ac.signal);
    const parsed = safeJson(finalOut.response);
    if (!parsed || parsed.trust_escape) return;

    const latency_ms = Date.now() - chunk.at;

    useEventBus.getState().emit({
      type: 'stat_card',
      player_id: parsed.player_id ?? '',
      stat_text: parsed.stat_text,
      source: parsed.source ?? 'Sportradar',
      latency_ms,
      confidence_high: Boolean(parsed.confidence_high),
    });

    if (parsed.precedent_id) {
      const hit = getMatchCache().precedent_index.find((p) => p.id === parsed.precedent_id);
      if (hit) {
        useEventBus.getState().emit({
          type: 'precedent',
          pattern_id: hit.id,
          stat_text: hit.stat_text,
          category: hit.category,
        });
      }
    }
    if (parsed.counter_narrative) {
      useEventBus.getState().emit({
        type: 'counter_narrative',
        text: parsed.counter_narrative.text,
        for_team: parsed.counter_narrative.for_team,
        tone: 'dramatic',
      });
    }
  }

  async processPressToTalk(audio: ArrayBuffer): Promise<void> {
    try {
      await this.processPressToTalkInner(audio);
    } catch (err) {
      if (isAbort(err)) return;
      throw err;
    }
  }

  private async processPressToTalkInner(audio: ArrayBuffer): Promise<void> {
    await this.client.ensureLoaded(DEFAULT_MODEL);
    const t0 = Date.now();
    const audioPcm = chunkToPcm(audio);
    const messages: CactusLMMessage[] = [
      { role: 'system', content: QUERY_OR_COMMAND_PROMPT },
      { role: 'user',   content: 'Transcribe and answer the press-to-talk audio.' },
    ];
    const out = await completeWithToolLoop(this.client, messages, TOOLS);
    const parsed = safeJson(out.response);
    const latency_ms = Date.now() - t0;
    const question = parsed?.transcript ?? '';
    void audioPcm;

    if (!parsed || parsed.trust_escape || parsed.intent === 'ungrounded') {
      useEventBus.getState().emit({ type: 'no_data', question });
      return;
    }

    if (parsed.intent === 'command' && parsed.widget_spec) {
      useEventBus.getState().emit({ type: 'widget_built', widget: parsed.widget_spec as WidgetSpec });
      return;
    }

    useEventBus.getState().emit({
      type: 'answer_card',
      question,
      answer: parsed.answer ?? '',
      source: parsed.source ?? 'Sportradar',
      confidence_high: Boolean(parsed.confidence_high),
      latency_ms,
    });
  }
}

// Convert ArrayBuffer (raw 16-bit PCM little-endian) to number[] of 16-bit samples.
// expo-av's HIGH_QUALITY preset is M4A by default — recordings need a separate
// decode step. The audio module is responsible for delivering already-PCM bytes;
// this helper is for the shape coercion.
function chunkToPcm(buf: ArrayBuffer): number[] {
  const view = new Int16Array(buf);
  const out = new Array(view.length);
  for (let i = 0; i < view.length; i++) out[i] = view[i];
  return out;
}
