import React from 'react';
import { Text, View } from 'react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

type Props = { small?: boolean };

export function SportradarBadge({ small = false }: Props) {
  const size = small ? 12 : 14;
  const fontSize = small ? 10 : 11;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
      <Svg viewBox="0 0 24 24" width={size} height={size}>
        <Circle cx="12" cy="12" r="10" fill="#10B981" fillOpacity={0.1} />
        <Circle cx="12" cy="12" r="9.5" stroke="#10B981" strokeWidth={1} fill="none" />
        <Path d="M7.5 12.5l3 3 6-6.5" stroke="#10B981" strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" fill="none" />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize, letterSpacing: 0.08 * fontSize, color: tokens.verified }}>
        Sportradar
      </Text>
    </View>
  );
}
