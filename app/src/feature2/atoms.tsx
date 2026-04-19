import React from 'react';
import { Animated, Text, View } from 'react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';

// Always-on "AI is listening" indicator — pulsing dot.
export function ListeningDot() {
  // RN can't do SMIL animation the way the SVG handoff does. Approximate with
  // Animated on the outer ring; the dot itself is static green.
  const pulse = React.useRef(new Animated.Value(0)).current;
  React.useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(pulse, { toValue: 1, duration: 2000, useNativeDriver: true }),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  const scale = pulse.interpolate({ inputRange: [0, 1], outputRange: [0.8, 1.8] });
  const opacity = pulse.interpolate({ inputRange: [0, 1], outputRange: [0.6, 0] });

  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
      <View style={{ width: 10, height: 10, alignItems: 'center', justifyContent: 'center' }}>
        <Animated.View
          style={{
            position: 'absolute',
            width: 10,
            height: 10,
            borderRadius: 5,
            borderWidth: 1,
            borderColor: tokens.verified,
            transform: [{ scale }],
            opacity,
          }}
        />
        <View style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: tokens.verified }} />
      </View>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.3, color: tokens.textSubtle }}>LISTENING</Text>
    </View>
  );
}

// Animated waveform bars — used during active listening.
export function Waveform({ color = tokens.text }: { color?: string }) {
  const bars = React.useMemo(() => [0, 1, 2, 3, 4, 5, 6, 7].map(() => new Animated.Value(0.3)), []);
  React.useEffect(() => {
    const loops = bars.map((bar, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.timing(bar, { toValue: 1, duration: 300 + i * 40, useNativeDriver: true }),
          Animated.timing(bar, { toValue: 0.3, duration: 300 + i * 40, useNativeDriver: true }),
        ]),
      ),
    );
    loops.forEach((l) => l.start());
    return () => loops.forEach((l) => l.stop());
  }, [bars]);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 3, marginLeft: 6, height: 16 }}>
      {bars.map((bar, i) => (
        <Animated.View
          key={i}
          style={{
            width: 3,
            height: 12,
            backgroundColor: color,
            opacity: 0.7,
            borderRadius: 1.5,
            transform: [{ scaleY: bar }],
          }}
        />
      ))}
    </View>
  );
}

// Latency tag — shown on stat cards and bottom bezel.
export function LatencyTag({ ms = '842ms' }: { ms?: string }) {
  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        paddingVertical: 4,
        paddingHorizontal: 8,
        borderWidth: 1,
        borderColor: tokens.borderSoft,
        borderRadius: 4,
      }}
    >
      <Svg viewBox="0 0 24 24" width={11} height={11} fill="none">
        <Circle cx={12} cy={13} r={8} stroke={tokens.textSubtle} strokeWidth={1.5} />
        <Path d="M12 9v4l2.5 2M9 2h6M12 2v3" stroke={tokens.textSubtle} strokeWidth={1.5} strokeLinecap="round" />
      </Svg>
      <Text style={{ fontFamily: FONT_MONO, fontSize: 10, letterSpacing: 0.8, color: tokens.textSubtle }}>{ms}</Text>
    </View>
  );
}

// Empty gridlines for running-score panel pre-KO.
export function EmptyGridlines({ label = 'KICK-OFF IN 12:00' }: { label?: string }) {
  return (
    <View style={{ gap: 6 }}>
      {[0, 1, 2, 3].map((i) => (
        <View key={i} style={{ flexDirection: 'row', height: 1, gap: 6 }}>
          {Array.from({ length: 28 }).map((_, k) => (
            <View key={k} style={{ width: 6, height: 1, backgroundColor: tokens.borderSoft }} />
          ))}
        </View>
      ))}
      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, letterSpacing: 1.8, color: tokens.textSubtle, marginTop: 4 }}>
        {label}
      </Text>
    </View>
  );
}

