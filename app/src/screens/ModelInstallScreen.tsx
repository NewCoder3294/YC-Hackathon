import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';
import { useModelLoader } from '../cactus/state/modelLoader';

const MODEL_SIZE_GB = 4.68;

export function ModelInstallScreen() {
  const status   = useModelLoader((s) => s.status);
  const progress = useModelLoader((s) => s.progress);
  const error    = useModelLoader((s) => s.error);
  const reset    = useModelLoader((s) => s.reset);
  const retry    = useModelLoader((s) => s.ensureLoaded);

  const pct = Math.max(0, Math.min(100, Math.round(progress * 100)));
  const downloadedGb = (progress * MODEL_SIZE_GB).toFixed(2);

  return (
    <View style={{ flex: 1, backgroundColor: tokens.bgBase, alignItems: 'center', justifyContent: 'center', padding: 32 }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 2.4, color: tokens.textMuted, fontWeight: '700', marginBottom: 10 }}>
        BROADCAST BRAIN \u00B7 GEMMA 4 INSTALL
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 22, fontWeight: '700', color: tokens.text, marginBottom: 6 }}>
        {status === 'error' ? 'Install failed' : 'Installing the on-device model'}
      </Text>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, marginBottom: 24, textAlign: 'center', maxWidth: 420 }}>
        {status === 'error'
          ? 'The download couldn\u2019t finish. Check your connection and try again. The model is ~4.68 GB and only needs to install once.'
          : `BroadcastBrain runs Gemma 4 locally for zero-latency voice. One-time ~${MODEL_SIZE_GB} GB download \u2014 leave the app open on Wi\u2011Fi.`}
      </Text>

      {status !== 'error' && (
        <>
          <View style={{ width: 420, height: 10, borderWidth: 1, borderColor: tokens.border, borderRadius: 4, overflow: 'hidden', marginBottom: 10 }}>
            <View style={{ width: `${pct}%`, height: '100%', backgroundColor: tokens.esoteric }} />
          </View>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.textMuted }}>
            {pct}%  \u00B7  {downloadedGb} / {MODEL_SIZE_GB} GB
          </Text>
          {!!error && (
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textMuted, marginTop: 12, maxWidth: 420, textAlign: 'center' }} numberOfLines={2}>
              {error}
            </Text>
          )}
        </>
      )}

      {status === 'error' && (
        <>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.live, marginBottom: 18, maxWidth: 420, textAlign: 'center' }} numberOfLines={3}>
            {error}
          </Text>
          <Pressable
            onPress={() => { reset(); void retry(); }}
            style={{ paddingVertical: 12, paddingHorizontal: 28, borderWidth: 1, borderColor: tokens.text, borderRadius: 6 }}
            accessibilityRole="button"
            accessibilityLabel="Retry download"
          >
            <Text style={{ fontFamily: FONT_MONO, fontSize: 12, fontWeight: '700', color: tokens.text, letterSpacing: 1.6 }}>
              RETRY
            </Text>
          </Pressable>
        </>
      )}
    </View>
  );
}
