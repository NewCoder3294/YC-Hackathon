import React from 'react';
import { Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';
import { SportradarBadge } from '../frame/SportradarBadge';

type Props = {
  nation: string;
  code: string;
  formation?: string;
  count: number;
  accent: string;
  showFormation?: boolean;
};

export function TeamHeaderF1({ nation, code, formation, count, accent, showFormation = true }: Props) {
  return (
    <View
      style={{
        paddingVertical: 10,
        paddingHorizontal: 16,
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
        backgroundColor: tokens.bgRaised,
        borderBottomWidth: 1,
        borderBottomColor: tokens.borderSoft,
      }}
    >
      <View style={{ width: 4, height: 20, backgroundColor: accent, borderRadius: 2 }} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', letterSpacing: 1.7, color: tokens.text }}>
        {nation}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>{code}</Text>
      {showFormation && formation && (
        <View
          style={{
            paddingVertical: 2,
            paddingHorizontal: 7,
            backgroundColor: tokens.bgSubtle,
            borderWidth: 1,
            borderColor: tokens.border,
            borderRadius: 3,
          }}
        >
          <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.6, color: tokens.esoteric }}>
            {formation}
          </Text>
        </View>
      )}
      <View style={{ marginLeft: 'auto', flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.3 }}>{count} PLAYERS</Text>
        <SportradarBadge small />
      </View>
    </View>
  );
}
