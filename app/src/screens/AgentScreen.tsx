import React, { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { IPadFrame } from '../frame/IPadFrame';
import { FONT_MONO, tokens } from '../theme/tokens';
import { VoiceQueryButton } from '../feature1/VoiceQueryButton';

// Agent home — the ambient "always listening" voice console. Pre-match,
// commentator docks here; the mic is the primary affordance and any recent
// queries persist as cards above. Bridges to Feature 2 during live play.
export function AgentScreen() {
  const [listening, setListening] = useState(false);

  return (
    <IPadFrame>
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 48 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 10,
            letterSpacing: 2.2,
            color: tokens.verified,
            fontWeight: '700',
          }}
        >
          ● AGENT · ALWAYS LISTENING
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 32,
            fontWeight: '700',
            color: tokens.text,
            marginTop: 14,
            letterSpacing: -0.64,
            textAlign: 'center',
          }}
        >
          Hey Brain —{'\n'}what do you want to know?
        </Text>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 13,
            color: tokens.textMuted,
            marginTop: 14,
            lineHeight: 20,
            maxWidth: 560,
            textAlign: 'center',
          }}
        >
          On-device Gemma 4. Under 1 second. Every answer sourced from Sportradar or StatsBomb — or
          <Text style={{ color: tokens.text }}> "I don't have verified data on that." </Text>
          Nothing else.
        </Text>

        {/* Example prompts */}
        <View style={{ marginTop: 32, gap: 10, width: '100%', maxWidth: 640 }}>
          {[
            'How many goals has Mbappé scored in World Cups?',
            'Compare Messi vs Pelé at age 35.',
            'Show me France\'s set-piece conversion this tournament.',
            'What was the highest-scoring final since 1970?',
          ].map((q) => (
            <Pressable key={q}>
              <View
                style={{
                  paddingVertical: 12,
                  paddingHorizontal: 16,
                  backgroundColor: tokens.bgRaised,
                  borderWidth: 1,
                  borderColor: tokens.borderSoft,
                  borderRadius: 6,
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 10,
                }}
              >
                <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
                  <Path d="M5 12l5 5 10-11" stroke={tokens.verified} strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" />
                </Svg>
                <Text
                  style={{
                    fontFamily: FONT_MONO,
                    fontSize: 12,
                    color: tokens.textMuted,
                    flex: 1,
                    letterSpacing: 0.1,
                  }}
                >
                  "{q}"
                </Text>
                <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.4 }}>
                  TAP TO SIMULATE
                </Text>
              </View>
            </Pressable>
          ))}
        </View>

        {/* Latency thesis badge */}
        <View
          style={{
            marginTop: 40,
            flexDirection: 'row',
            alignItems: 'center',
            gap: 24,
          }}
        >
          <Metric label="LATENCY"     value="842" unit="ms" accent={tokens.verified} />
          <Metric label="ACCURACY"    value="100" unit="%"  accent={tokens.verified} />
          <Metric label="CLOUD CALLS" value="0"   unit="·"  accent={tokens.esoteric} />
        </View>
      </View>

      <VoiceQueryButton listening={listening} onPress={() => setListening((l) => !l)} />
    </IPadFrame>
  );
}

function Metric({ label, value, unit, accent }: { label: string; value: string; unit: string; accent: string }) {
  return (
    <View style={{ alignItems: 'center' }}>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.8, color: tokens.textSubtle, fontWeight: '700' }}>
        {label}
      </Text>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', marginTop: 4, gap: 3 }}>
        <Text
          style={{
            fontFamily: FONT_MONO,
            fontSize: 30,
            fontWeight: '700',
            color: accent,
            letterSpacing: -0.6,
            fontVariant: ['tabular-nums'] as any,
          }}
        >
          {value}
        </Text>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted }}>{unit}</Text>
      </View>
    </View>
  );
}
