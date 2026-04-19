// Validates the Gemma 4 prompt stack + match-cache against bundled WAV fixtures.
// Requires the `cactus` CLI in PATH and `google/gemma-4-E2B-it` already
// downloaded (run `cactus download google/gemma-4-E2B-it` once).

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { loadMatchCache } from '../src/cactus/state/matchCache';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT } from '../src/cactus/prompts';

const MODEL_ID = 'google/gemma-4-E2B-it';
const FIXTURES = ['messi-pen-23', 'dimaria-36', 'mbappe-pen-80', 'mbappe-81'];

loadMatchCache(JSON.parse(readFileSync(join(__dirname, '../assets/match_cache.json'), 'utf-8')));

for (const name of FIXTURES) {
  const wavPath = join(__dirname, `../assets/audio-fixtures/${name}.wav`);
  console.log('\n── ' + name + ' ' + '─'.repeat(Math.max(0, 40 - name.length)));

  if (!existsSync(wavPath)) {
    console.log(`  (skip — fixture missing at ${wavPath} — see audio-fixtures/README.md)`);
    continue;
  }

  const classifyRaw = runCactus(AUTONOMOUS_PROMPT, wavPath);
  console.log('classify raw:', truncate(classifyRaw, 400));

  const classify = extractJson(classifyRaw);
  if (!classify) {
    console.log('  (skip — classifier output was not valid JSON)');
    continue;
  }
  console.log('classify parsed:', classify);

  if (!classify.stat_opportunity) {
    console.log('  (skip — classifier says no opportunity)');
    continue;
  }

  const generateSystem = [
    GENERATE_PROMPT,
    `EVENT_TYPE=${classify.event_type ?? 'unknown'}`,
    `PLAYERS=${(classify.players_mentioned ?? []).join(',')}`,
  ].join('\n');

  const generateRaw = runCactus(generateSystem, wavPath);
  console.log('generate raw:', truncate(generateRaw, 600));

  const generated = extractJson(generateRaw);
  console.log('generate parsed:', generated);
}

function runCactus(systemPrompt: string, audioPath: string): string {
  // `cactus run` opens an interactive REPL. We feed `exit` on stdin so it
  // produces one assistant turn then quits.
  const res = spawnSync(
    'cactus',
    [
      'run', MODEL_ID,
      '--system', systemPrompt,
      '--prompt', 'Respond as instructed in the system message.',
      '--audio', audioPath,
      '--no-thinking',
    ],
    { input: 'exit\n', encoding: 'utf-8', maxBuffer: 8 * 1024 * 1024 },
  );
  return (res.stdout ?? '') + (res.stderr ?? '');
}

// Cactus's REPL output wraps JSON inside ANSI/banner text. Strip ANSI, then
// pull the longest brace-balanced JSON object from the response area.
function extractJson(raw: string): any | null {
  const cleaned = raw.replace(/\x1b\[[0-9;]*m/g, '');
  const matches = cleaned.match(/\{[\s\S]*?\}/g);
  if (!matches) return null;
  for (const candidate of matches.sort((a, b) => b.length - a.length)) {
    try { return JSON.parse(candidate); } catch { /* keep trying */ }
  }
  return null;
}

function truncate(s: string, n: number): string {
  if (s.length <= n) return s;
  return s.slice(0, n) + ` …(+${s.length - n} chars)`;
}
