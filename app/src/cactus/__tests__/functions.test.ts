import * as fns from '../functions';
import { loadMatchCache, __resetMatchCacheForTests } from '../state/matchCache';

const raw = require('../../../assets/match_cache.json');

beforeEach(() => {
  __resetMatchCacheForTests();
  loadMatchCache(raw);
});

describe('get_player_stat', () => {
  it('direct tournament-goals lookup returns stat + source + high confidence', () => {
    const r = fns.get_player_stat('Messi', 'current_tournament');
    expect(r).not.toBeNull();
    expect(r!.value).toBe(5);
    expect(r!.source).toBeDefined();
    expect(r!.confidence_high).toBe(true);
  });

  it('resolves by last name', () => {
    const r = fns.get_player_stat('mbappé');
    expect(r).not.toBeNull();
    expect(r!.stat_text).toMatch(/Mbappé/i);
  });

  it('returns null for ambiguous names (no match)', () => {
    const r = fns.get_player_stat('Nobody', 'career');
    expect(r).toBeNull();
  });
});

describe('get_team_stat', () => {
  it('returns tournament record for arg', () => {
    const r = fns.get_team_stat('arg', 'record');
    expect(r).not.toBeNull();
    expect(r!.stat_text).toMatch(/5-1-1|5W/i);
  });

  it('null for unknown metric', () => {
    expect(fns.get_team_stat('arg', 'frobnicate_level')).toBeNull();
  });
});

describe('get_historical', () => {
  it('returns eligible precedents for 2-0 goal trigger', () => {
    const r = fns.get_historical('2-0 lead in WC Final');
    expect(r.length).toBeGreaterThan(0);
    expect(r[0].trigger.score_state).toBe('2-0');
  });

  it('returns [] when nothing matches', () => {
    expect(fns.get_historical('nonsense query with no match')).toEqual([]);
  });
});

describe('get_match_context', () => {
  it('returns a sane default match state', () => {
    const r = fns.get_match_context('arg-vs-fra-2022-wc-final');
    expect(r.score).toEqual({ home: 0, away: 0 });
    expect(r.phase).toBe('pre_match');
  });
});
