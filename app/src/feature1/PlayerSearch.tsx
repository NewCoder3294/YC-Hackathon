import React from 'react';
import { TextInput, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

type Props = {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
};

export function PlayerSearch({ value, onChange, placeholder = 'FILTER PLAYERS…' }: Props) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        paddingVertical: 8,
        paddingHorizontal: 10,
        marginHorizontal: 12,
        marginTop: 10,
        backgroundColor: tokens.bgSubtle,
        borderWidth: 1,
        borderColor: tokens.borderSoft,
        borderRadius: 5,
      }}
    >
      <Svg width={12} height={12} viewBox="0 0 16 16" fill="none">
        <Path
          d="M7 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM11 11l3 3"
          stroke={tokens.textSubtle}
          strokeWidth={1.5}
          strokeLinecap="round"
        />
      </Svg>
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor={tokens.textSubtle}
        style={
          {
            flex: 1,
            fontFamily: FONT_MONO,
            fontSize: 11,
            letterSpacing: 1.4,
            color: tokens.text,
            outlineStyle: 'none', // web-only — kills default focus ring
          } as any
        }
      />
    </View>
  );
}
