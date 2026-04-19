import { CactusClient } from '../client';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT, QUERY_OR_COMMAND_PROMPT } from '../prompts';
import * as functions from '../functions';
import { Gate } from './gate';
import { Dedupe } from './dedupe';
import { useEventBus, WidgetSpec } from '../state/eventBus';
import type { Chunk } from '../audio/continuous';
import { getMatchCache } from '../state/matchCache';

const MODEL_ID = 'google/functiongemma-270m-it';

const TOOLS = {
  get_player_stat: functions.get_player_stat,
  get_team_stat: functions.get_team_stat,
  get_match_context: functions.get_match_context,
  get_historical: functions.get_historical,
  get_commentator_profile: functions.get_commentator_profile,
};

function isAbort(err: unknown): boolean {
  return err instanceof Error && /abort/i.test(err.message);
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

    await this.client.ensureLoaded(MODEL_ID);

    const classify = await this.gate.classify(chunk.audio, async (audio) => {
      const out = await this.client.generate({
        prompt: AUTONOMOUS_PROMPT,
        audio,
        signal: ac.signal,
      });
      return JSON.parse(out);
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

    const prompt = buildGeneratePrompt(classify);
    const raw = await this.client.generate({ prompt, tools: TOOLS, signal: ac.signal });
    const parsed = safeJson(raw);
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
    await this.client.ensureLoaded(MODEL_ID);
    const t0 = Date.now();
    const raw = await this.client.generate({ prompt: QUERY_OR_COMMAND_PROMPT, audio, tools: TOOLS });
    const parsed = safeJson(raw);
    const latency_ms = Date.now() - t0;
    const question = parsed?.transcript ?? '';

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

function buildGeneratePrompt(classify: { event_type?: string | null; players_mentioned?: string[] }): string {
  const ctx = functions.get_match_context('arg-vs-fra-2022-wc-final');
  return [
    GENERATE_PROMPT,
    `EVENT_TYPE=${classify.event_type ?? 'unknown'}`,
    `PLAYERS=${(classify.players_mentioned ?? []).join(',')}`,
    `MATCH_STATE=${JSON.stringify({ score: ctx.score, minute: ctx.minute, phase: ctx.phase })}`,
  ].join('\n');
}

function safeJson(raw: string): any {
  try { return JSON.parse(raw); } catch { return null; }
}
