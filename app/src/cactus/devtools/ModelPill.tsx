import React from 'react';
import { Text, View } from 'react-native';
import { useModelLoader } from '../state/modelLoader';
import { FONT_MONO, tokens } from '../../theme/tokens';

export function ModelPill() {
  const status   = useModelLoader((s) => s.status);
  const progress = useModelLoader((s) => s.progress);
  const error    = useModelLoader((s) => s.error);

  if (status === 'ready') return null;

  const label =
    status === 'unloaded'    ? 'GEMMA · INIT' :
    status === 'downloading' ? `GEMMA · DL ${Math.round(progress * 100)}%` :
    status === 'loading'     ? 'GEMMA · LOAD' :
                               `GEMMA · ERR`;
  const color =
    status === 'error' ? tokens.live :
                         tokens.esoteric;

  return (
    <View
      style={{
        position: 'absolute',
        top: 12,
        left: '50%',
        transform: [{ translateX: -90 }],
        width: 180,
        paddingVertical: 6,
        paddingHorizontal: 10,
        backgroundColor: tokens.bgRaised,
        borderWidth: 1,
        borderColor: color,
        borderRadius: 999,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        zIndex: 100,
      }}
    >
      <View style={{ width: 6, height: 6, borderRadius: 999, backgroundColor: color }} />
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, fontWeight: '700', letterSpacing: 1.5, color }}>
        {label}
      </Text>
      {!!error && status === 'error' && (
        <Text style={{ fontFamily: FONT_MONO, fontSize: 8, color: tokens.textMuted, marginLeft: 6, maxWidth: 80 }} numberOfLines={1}>
          {error}
        </Text>
      )}
    </View>
  );
}
