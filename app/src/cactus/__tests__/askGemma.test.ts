jest.mock('../client', () => {
  return {
    CactusClient: class {
      async ensureLoaded() {}
      async generate(opts: any) {
        if (opts.prompt?.includes('press-to-talk audio recording')) {
          return JSON.stringify({
            transcript: 'how many goals has mbappe scored',
            intent: 'query',
            answer: 'Mbappé has 9 WC career goals.',
            source: 'Sportradar',
            confidence_high: true,
            widget_spec: null,
            trust_escape: false,
          });
        }
        return JSON.stringify({ transcript: '', stat_opportunity: false });
      }
    },
  };
});

import { askGemma } from '../askGemma';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(require('../../../assets/match_cache.json'));
});

describe('askGemma (press-to-talk)', () => {
  it('returns a grounded answer for a QUERY intent', async () => {
    const audio = new ArrayBuffer(1024);
    const r = await askGemma(
      { audio },
      {
        mode: 'stats_first',
        match_state: {
          score: { home: 0, away: 0 }, minute: 0, added_time: null, phase: 'pre_match',
          possession_pct: { home: 50, away: 50 },
          shots: { home: 0, away: 0 }, shots_on_target: { home: 0, away: 0 }, recent_events: [],
        },
        recent_transcripts: [],
        commentator_profile: require('../functions').get_commentator_profile(),
      },
      'local',
    );
    expect(r.stat_text).toMatch(/Mbapp/i);
    expect(r.source).toBe('Sportradar');
    expect(r.confidence_high).toBe(true);
    expect(r.latency_ms).toBeGreaterThanOrEqual(0);
  });
});
