import { MatchCache, MatchCacheSchema } from '../schema';

let cached: MatchCache | null = null;

export function loadMatchCache(raw: unknown): MatchCache {
  if (cached) return cached;
  const parsed = MatchCacheSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(`match_cache.json failed schema validation: ${parsed.error.message}`);
  }
  cached = parsed.data;
  return cached;
}

export function getMatchCache(): MatchCache {
  if (!cached) throw new Error('match_cache not loaded — call loadMatchCache() at app startup');
  return cached;
}

// Test-only: reset the memoized instance between specs.
export function __resetMatchCacheForTests() {
  cached = null;
}
