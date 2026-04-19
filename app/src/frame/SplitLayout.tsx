import React from 'react';
import { View } from 'react-native';
import { tokens } from '../theme/tokens';

type Props = {
  left: React.ReactNode;
  right: React.ReactNode;
  // handoff uses 60 / 40 — matches SPEC.md §Shared Architecture.
  leftFlex?: number;
  rightFlex?: number;
};

export function SplitLayout({ left, right, leftFlex = 60, rightFlex = 40 }: Props) {
  return (
    <View style={{ flex: 1, flexDirection: 'row' }}>
      <View
        style={{
          flex: leftFlex,
          borderRightWidth: 1,
          borderRightColor: tokens.border,
          overflow: 'hidden',
          backgroundColor: tokens.bgBase,
        }}
      >
        {left}
      </View>
      <View style={{ flex: rightFlex, overflow: 'hidden', backgroundColor: tokens.bgBase }}>
        {right}
      </View>
    </View>
  );
}
