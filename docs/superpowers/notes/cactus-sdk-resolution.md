# Cactus RN SDK Resolution

**Status:** PENDING (manual iPad spike)

The Cactus RN SDK has not yet been installed in `app/`. The voice pipeline
is built against the assumed import surface:

```ts
const { Cactus } = require('cactus-react-native');
Cactus.load({ model: string }) → Promise<{ sessionId }>
Cactus.generate({ sessionId, prompt?, audio?, tools? }) → Promise<string>
Cactus.close({ sessionId }) → Promise<void>
```

Tests mock this module via `app/__mocks__/cactus-react-native.ts` + jest's
`moduleNameMapper`. The real SDK package name and method names must be
confirmed during the iPad spike (SPEC Open Question 1). When confirmed:

1. Install the real package (likely `cactus-react-native` or
   `github:cactus-compute/cactus#main`).
2. If method names differ, adjust `app/src/cactus/client.ts` only —
   everything downstream uses `CactusClient`, not the raw SDK.
3. Delete or update the jest mock only if the new SDK can load in the
   jest environment without native bindings (unlikely; keep the mock).

Resolved by: _pending_
Date: _pending_
