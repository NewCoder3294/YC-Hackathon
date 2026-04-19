import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { loadMatchCache } from '../src/cactus/state/matchCache';
import { AUTONOMOUS_PROMPT, GENERATE_PROMPT } from '../src/cactus/prompts';

const FIXTURES = ['messi-pen-23', 'dimaria-36', 'mbappe-pen-80', 'mbappe-81'];

loadMatchCache(JSON.parse(readFileSync(join(__dirname, '../assets/match_cache.json'), 'utf-8')));

for (const name of FIXTURES) {
  const wavPath = join(__dirname, `../assets/audio-fixtures/${name}.wav`);
  console.log('\n── ' + name + ' ' + '─'.repeat(Math.max(0, 40 - name.length)));

  const classifyOut = runCactus(AUTONOMOUS_PROMPT, wavPath);
  console.log('classify:', classifyOut);

  let classify: { stat_opportunity?: boolean; event_type?: string; players_mentioned?: string[] };
  try {
    classify = JSON.parse(classifyOut);
  } catch {
    console.log('  (skip — classifier output was not valid JSON)');
    continue;
  }
  if (!classify.stat_opportunity) {
    console.log('  (skip — classifier says no opportunity)');
    continue;
  }

  const generatePrompt = [
    GENERATE_PROMPT,
    `EVENT_TYPE=${classify.event_type ?? 'unknown'}`,
    `PLAYERS=${(classify.players_mentioned ?? []).join(',')}`,
  ].join('\n');
  const generateOut = runCactus(generatePrompt, wavPath);
  console.log('generate:', generateOut);
}

function runCactus(prompt: string, audioPath: string): string {
  const out = execFileSync(
    'cactus',
    [
      'generate',
      '--model', 'google/functiongemma-270m-it',
      '--prompt', prompt,
      '--audio', audioPath,
      '--json',
    ],
    { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'inherit'] },
  );
  return out.trim();
}
