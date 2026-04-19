import React from 'react';
import { View, ViewStyle } from 'react-native';
import { tokens } from '../theme/tokens';
import { BackgroundPattern, usePatternContext } from '../ui/BackgroundPattern';

type Props = {
  children: React.ReactNode;
  bg?: string;
  style?: ViewStyle;
  hidePattern?: boolean;
};

// Fills its container (flex: 1). On iPad that's 1366×1024 natively in landscape;
// on a laptop browser it's whatever the viewport is. The animated background
// pattern is pulled from context so App.tsx can cycle it without prop-drilling.
export function IPadFrame({ children, bg = tokens.bgBase, style, hidePattern = false }: Props) {
  const { pattern } = usePatternContext();
  return (
    <View style={[{ flex: 1, overflow: 'hidden', position: 'relative' }, style]}>
      <View
        pointerEvents="none"
        style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: bg }}
      />
      {!hidePattern && <BackgroundPattern pattern={pattern} />}
      <View style={{ flex: 1 }}>{children}</View>
    </View>
  );
}
