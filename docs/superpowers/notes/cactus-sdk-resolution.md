# Cactus RN SDK Resolution

**Status:** RESOLVED on macOS 2026-04-18; iPad install still pending physical-device test.

## What's wired

- npm package: `cactus-react-native@1.13.1` (also requires peer `react-native-nitro-modules`)
- Audio-multimodal model: **`google/gemma-4-E2B-it`** (~6.3 GB INT4)
  - NOT `google/functiongemma-270m-it` — that one is text-only function calling
- Real API surface (now wired in `app/src/cactus/client.ts`):

```ts
import { CactusLM, type CactusLMMessage, type CactusLMTool } from 'cactus-react-native';

const lm = new CactusLM({ model: 'google/gemma-4-E2B-it', options: { quantization: 'int4' } });
await lm.download({ onProgress });
const result = await lm.complete({ messages, tools, audio /* number[] PCM */ });
// result.response, result.functionCalls
await lm.destroy();
```

## Verified end-to-end on this machine

- `cactus auth` succeeded with the project key
- `cactus download google/gemma-4-E2B-it` landed weights at
  `/opt/homebrew/Cellar/cactus/<ver>/libexec/weights/gemma-4-e2b-it/`
- `npx tsx app/scripts/smoke-text.ts` runs Gemma 4 against three prompts:
  - "How many goals has Mbappé scored in this tournament?" → grounded query (PASS)
  - "What is Messi's tournament goal count?" → `answer: 5` from grounded data (PASS)
  - "What is Mbappé's favourite food?" → `intent: 'ungrounded', trust_escape: true` (PASS)
- Latency: ~4 s with model load, ~1 s decode after warmup
- 30/30 unit tests still green against the new client API

## iPad bring-up — what's still required

1. Install Xcode + provisioning. Cactus is a native RN module that **does not work in Expo Go**.
2. From `app/`:
   ```
   npx expo prebuild --clean
   npx expo run:ios --device
   ```
   Or build a custom dev client via EAS:
   ```
   eas build --profile development --platform ios
   ```
3. First app launch will trigger `CactusLM.download(...)` (6.3 GB) — pre-download via the CLI to skip this.
4. Run with `?devtools` query (web) or flip `setShowDevtools(true)` in `App.tsx` to expose the rehearsal overlay.

## Known gaps (not blockers)

- `expo-av` records to M4A by default. The orchestrator currently coerces
  `ArrayBuffer` → `Int16Array` → `number[]`, which assumes raw 16-bit PCM. If
  expo-av delivers an M4A container, we need to decode it first (e.g. via a
  native module or an offline conversion step). Validate this on first iPad run.
- The CLI smoke harness uses `cactus run --audio` with WAV fixtures — see
  `app/assets/audio-fixtures/README.md` for how to produce them.

Resolved by: Cactus track agent
Date: 2026-04-18
