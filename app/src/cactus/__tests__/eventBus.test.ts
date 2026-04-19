import { useEventBus } from '../state/eventBus';

describe('eventBus', () => {
  beforeEach(() => {
    useEventBus.setState({ events: [] });
  });

  it('emits and stores a stat_card event', () => {
    useEventBus.getState().emit({
      type: 'stat_card',
      player_id: 'arg-10',
      stat_text: '6th goal of tournament',
      source: 'Sportradar',
      latency_ms: 842,
      confidence_high: true,
    });
    const all = useEventBus.getState().events;
    expect(all).toHaveLength(1);
    expect(all[0].type).toBe('stat_card');
  });

  it('returns the latest event of a given type', () => {
    const state = useEventBus.getState();
    state.emit({ type: 'transcript', text: 'hello',   confidence: 0.9 });
    state.emit({ type: 'transcript', text: 'goodbye', confidence: 0.8 });
    const latest = state.latest('transcript');
    expect(latest?.text).toBe('goodbye');
  });

  it('caps event history at 200 items', () => {
    const state = useEventBus.getState();
    for (let i = 0; i < 250; i++) {
      state.emit({ type: 'transcript', text: String(i), confidence: 1 });
    }
    expect(useEventBus.getState().events).toHaveLength(200);
  });
});
