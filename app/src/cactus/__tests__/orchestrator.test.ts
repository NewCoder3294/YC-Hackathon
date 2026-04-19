jest.mock('../client', () => {
  let call = 0;
  return {
    CactusClient: class {
      async ensureLoaded() {}
      async generate() {
        call++;
        if (call === 1) {
          return JSON.stringify({
            transcript: 'messi scores from the spot',
            stat_opportunity: true,
            event_type: 'goal',
            players_mentioned: ['messi'],
            score_state_changed: true,
          });
        }
        return JSON.stringify({
          stat_text: 'Messi 6th of tournament · 2nd WC Final goal of career',
          source: 'Sportradar',
          player_id: 'arg-10',
          confidence_high: true,
          precedent_id: 'p-score-first-wc-final',
          counter_narrative: { text: 'France came back in 2018.', for_team: 'away' },
          trust_escape: false,
        });
      }
    },
  };
});

import { Orchestrator } from '../pipeline/orchestrator';
import { useEventBus } from '../state/eventBus';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(require('../../../assets/match_cache.json'));
  useEventBus.setState({ events: [] });
});

describe('Orchestrator.processAutonomousChunk', () => {
  it('emits stat_card + precedent + counter_narrative on an opportunity', async () => {
    const orch = new Orchestrator();
    await orch.processAutonomousChunk({
      audio: new ArrayBuffer(1024),
      stats: { peakDb: -20, voicedFrames: 16, totalFrames: 20 },
      at: Date.now(),
    });
    const types = useEventBus.getState().events.map((e) => e.type);
    expect(types).toContain('stat_card');
    expect(types).toContain('precedent');
    expect(types).toContain('counter_narrative');
  });

  it('drops silent chunks at VAD', async () => {
    const orch = new Orchestrator();
    await orch.processAutonomousChunk({
      audio: new ArrayBuffer(1024),
      stats: { peakDb: -55, voicedFrames: 0, totalFrames: 20 },
      at: Date.now(),
    });
    expect(useEventBus.getState().events).toHaveLength(0);
  });
});
