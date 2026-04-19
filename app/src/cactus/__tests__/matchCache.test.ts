import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

describe('matchCache loader', () => {
  beforeEach(() => __resetMatchCacheForTests());

  it('loads and validates a well-formed cache', () => {
    const raw = require('../../../assets/match_cache.json');
    const cache = loadMatchCache(raw);
    expect(cache.match.id).toBe('arg-vs-fra-2022-wc-final');
    expect(cache.players.length).toBeGreaterThan(0);
  });

  it('throws on malformed cache', () => {
    expect(() => loadMatchCache({ garbage: true })).toThrow(/match_cache/i);
  });

  it('is idempotent — second call returns the same instance', () => {
    const raw = require('../../../assets/match_cache.json');
    const a = loadMatchCache(raw);
    const b = loadMatchCache(raw);
    expect(a).toBe(b);
  });
});
