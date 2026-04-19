import React, { useRef } from 'react';
import { Animated, Pressable, Text, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

// Persistent press-to-talk button — lives on the bottom bezel of the iPad,
// anchored both-thumbs-reach per SPEC §Feature 3. Feature 1 wires it as a
// visual-only stub (shows "LISTENING…" overlay), wiring to askGemma() happens
// when the voice track is built.
type Props = {
  onPress?: () => void;
  listening?: boolean;
};

export function VoiceQueryButton({ onPress, listening = false }: Props) {
  const pulse = useRef(new Animated.Value(1)).current;

  React.useEffect(() => {
    if (!listening) { pulse.setValue(1); return; }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1.12, duration: 500, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 1.0,  duration: 500, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [listening, pulse]);

  const accent = listening ? tokens.live : tokens.text;

  return (
    <View
      style={{
        position: 'absolute',
        bottom: 22,
        left: 0,
        right: 0,
        alignItems: 'center',
        zIndex: 5,
      }}
      pointerEvents="box-none"
    >
      <Pressable onPress={onPress} hitSlop={12}>
        <Animated.View
          style={{
            transform: [{ scale: pulse }],
            width: 196,
            paddingVertical: 14,
            paddingHorizontal: 18,
            borderRadius: 999,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
            backgroundColor: listening ? 'rgba(239,68,68,0.12)' : tokens.bgRaised,
            borderWidth: 1,
            borderColor: listening ? tokens.live : tokens.border,
            boxShadow: listening
              ? '0 0 0 6px rgba(239,68,68,0.2), 0 10px 30px rgba(0,0,0,0.6)'
              : '0 10px 30px rgba(0,0,0,0.55)',
          }}
        >
          <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
            <Path
              d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z"
              stroke={accent}
              strokeWidth={1.6}
              strokeLinejoin="round"
            />
            <Path
              d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8"
              stroke={accent}
              strokeWidth={1.6}
              strokeLinecap="round"
            />
          </Svg>
          <Text
            style={{
              fontFamily: FONT_MONO,
              fontSize: 12,
              fontWeight: '700',
              letterSpacing: 2.2,
              color: accent,
            }}
          >
            {listening ? 'LISTENING…' : 'HEY BRAIN'}
          </Text>
        </Animated.View>
      </Pressable>
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 9,
          letterSpacing: 1.4,
          color: tokens.textSubtle,
          marginTop: 6,
        }}
      >
        HOLD TO TALK · &lt;1S ON-DEVICE · AIRPLANE-MODE SAFE
      </Text>
    </View>
  );
}
