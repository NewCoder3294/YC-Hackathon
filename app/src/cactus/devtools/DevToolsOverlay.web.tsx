// Web stub for DevToolsOverlay.
//
// The native DevToolsOverlay pulls in cactus-react-native → react-native-nitro-modules
// → react-native internals that don't exist on web (TurboModuleRegistry 'SourceCode').
// Metro's platform resolution picks this file on web builds, keeping the native-only
// code path out of the web bundle entirely. The devtools overlay is iPad-only, so
// a no-op on web is fine.
import React from 'react';

export function DevToolsOverlay(_: { onClose: () => void }) {
  return null;
}
