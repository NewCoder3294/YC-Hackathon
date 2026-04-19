// The legacy NativeAnimatedHelper path was removed in RN 0.73+. Use a virtual
// mock so older guidance still works without a module-resolution error.
jest.mock('react-native/Libraries/Animated/NativeAnimatedHelper', () => ({}), {
  virtual: true,
});
