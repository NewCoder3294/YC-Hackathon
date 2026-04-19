export type VadStats = { peakDb: number; voicedFrames: number; totalFrames: number };

export type Classification = {
  transcript: string;
  stat_opportunity: boolean;
  event_type?: 'goal' | 'shot' | 'card' | 'sub' | 'milestone' | null;
  players_mentioned?: string[];
  score_state_changed?: boolean;
};

export type OpportunityClassifier = (audio: ArrayBuffer) => Promise<unknown>;

const PEAK_DB_THRESHOLD = -40;
const MIN_VOICED_FRAMES = 8;

export class Gate {
  vadAccept(stats: VadStats): boolean {
    if (stats.peakDb < PEAK_DB_THRESHOLD) return false;
    if (stats.voicedFrames < MIN_VOICED_FRAMES) return false;
    return true;
  }

  async classify(audio: ArrayBuffer, classifier: OpportunityClassifier): Promise<Classification> {
    try {
      const raw = await classifier(audio);
      return normalizeClassification(raw);
    } catch {
      return { transcript: '', stat_opportunity: false };
    }
  }
}

function normalizeClassification(raw: unknown): Classification {
  if (!raw || typeof raw !== 'object') return { transcript: '', stat_opportunity: false };
  const r = raw as Record<string, unknown>;
  if (typeof r.stat_opportunity !== 'boolean') {
    return { transcript: String(r.transcript ?? ''), stat_opportunity: false };
  }
  return {
    transcript: String(r.transcript ?? ''),
    stat_opportunity: r.stat_opportunity,
    event_type: (r.event_type as Classification['event_type']) ?? null,
    players_mentioned: Array.isArray(r.players_mentioned) ? r.players_mentioned.map(String) : [],
    score_state_changed: Boolean(r.score_state_changed),
  };
}
