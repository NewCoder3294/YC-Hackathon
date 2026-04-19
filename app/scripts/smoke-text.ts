// Quick text-only smoke test against the real Gemma 4 model via the Cactus CLI.
// Verifies prompts produce sensible JSON for the demo's grounded-answer path
// without needing audio fixtures yet.
//
// Run: npx tsx scripts/smoke-text.ts

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { loadMatchCache } from '../src/cactus/state/matchCache';
import { QUERY_OR_COMMAND_PROMPT } from '../src/cactus/prompts';
import * as functions from '../src/cactus/functions';

const MODEL_ID = 'google/gemma-4-E2B-it';

loadMatchCache(JSON.parse(readFileSync(join(__dirname, '../assets/match_cache.json'), 'utf-8')));

const cases = [
  { q: 'How many goals has Mbappé scored in this tournament?', expectGround: true },
  { q: "What is Messi's tournament goal count?",               expectGround: true },
  { q: 'What is Mbappé\'s favourite food?',                    expectGround: false },
];

const groundingHint = [
  'Available grounded data:',
  `- ${JSON.stringify(functions.get_player_stat('messi', 'current_tournament'))}`,
  `- ${JSON.stringify(functions.get_player_stat('mbappe', 'current_tournament'))}`,
].join('\n');

for (const { q, expectGround } of cases) {
  console.log(`\n── ${q.slice(0, 50)}${q.length > 50 ? '…' : ''}`);
  const system = `${QUERY_OR_COMMAND_PROMPT}\n\n${groundingHint}`;
  const raw = runCactus(system, q);
  console.log('raw (truncated):', raw.replace(/\x1b\[[0-9;]*m/g, '').slice(0, 800));
  const parsed = extractJson(raw);
  console.log('parsed:', parsed);
  if (parsed) {
    const actuallyGrounded = !parsed.trust_escape && parsed.intent !== 'ungrounded';
    const passed = actuallyGrounded === expectGround;
    console.log(passed ? '  ✓ PASS' : '  ✗ FAIL — expected grounded=' + expectGround);
  } else {
    console.log('  ✗ FAIL — no JSON in output');
  }
}

function runCactus(systemPrompt: string, userPrompt: string): string {
  const res = spawnSync(
    'cactus',
    [
      'run', MODEL_ID,
      '--system', systemPrompt,
      '--prompt', userPrompt,
      '--no-thinking',
    ],
    { input: 'exit\n', encoding: 'utf-8', maxBuffer: 8 * 1024 * 1024 },
  );
  return (res.stdout ?? '') + (res.stderr ?? '');
}

function extractJson(raw: string): any | null {
  const cleaned = raw.replace(/\x1b\[[0-9;]*m/g, '').replace(/\/\/[^\n]*/g, '');
  const candidates: string[] = [];
  for (let i = 0; i < cleaned.length; i++) {
    if (cleaned[i] !== '{') continue;
    let depth = 0;
    let inStr = false;
    let escape = false;
    for (let j = i; j < cleaned.length; j++) {
      const ch = cleaned[j];
      if (escape) { escape = false; continue; }
      if (ch === '\\') { escape = true; continue; }
      if (ch === '"') inStr = !inStr;
      if (inStr) continue;
      if (ch === '{') depth++;
      else if (ch === '}') {
        depth--;
        if (depth === 0) { candidates.push(cleaned.slice(i, j + 1)); break; }
      }
    }
  }
  for (const c of candidates.sort((a, b) => b.length - a.length)) {
    try { return JSON.parse(c); } catch { /* keep trying */ }
  }
  return null;
}
