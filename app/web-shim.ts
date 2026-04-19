// Web dev-mode shim.
//
// Expo's dev build installs a throw-getter on `global.__fbBatchedBridgeConfig`
// so any accidental import from `react-native` (instead of `react-native-web`)
// produces a clear error. Some transitive deps (e.g. react-native-worklets used
// by react-native-reanimated v4) trigger this read on web even when the code
// they gate is never executed, which crashes the app shell.
//
// Pre-defining the property with a benign empty-object value makes Expo's
// `'__fbBatchedBridgeConfig' in global` check see the key and skip installing
// the throwing getter. Must run BEFORE `import 'expo'` anywhere in the graph.
if (typeof globalThis !== 'undefined') {
  const g = globalThis as unknown as { __fbBatchedBridgeConfig?: unknown };
  if (!('__fbBatchedBridgeConfig' in g)) {
    Object.defineProperty(g, '__fbBatchedBridgeConfig', {
      value: {},
      writable: true,
      configurable: true,
    });
  }
}

export {};
