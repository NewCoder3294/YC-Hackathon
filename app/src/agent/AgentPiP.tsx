import React, { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, {
  Easing,
  FadeIn,
  FadeOut,
  Layout,
  interpolate,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withDecay,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Svg, { Path, Rect } from 'react-native-svg';
import { FONT_MONO, tokens } from '../theme/tokens';
import { useAgent } from './AgentContext';

type Props = {
  onExpand: () => void;
};

// Zoom-style picture-in-picture widget with a collapsed circle mode.
// Header drag + bubble drag both run on the UI thread via Reanimated.
export function AgentPiP({ onExpand }: Props) {
  const { active, points, hidePiP } = useAgent();
  const [collapsed, setCollapsed] = useState(false);

  const tx = useSharedValue(0);
  const ty = useSharedValue(0);

  const dragStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: tx.value }, { translateY: ty.value }],
  }));

  const panGesture = Gesture.Pan()
    .activeOffsetX([-4, 4])
    .activeOffsetY([-4, 4])
    .onChange((e) => {
      tx.value += e.changeX;
      ty.value += e.changeY;
    })
    .onEnd((e) => {
      tx.value = withDecay({ velocity: e.velocityX, clamp: [-600, 600] });
      ty.value = withDecay({ velocity: e.velocityY, clamp: [-400, 400] });
    });

  const pulse = useSharedValue(0);
  React.useEffect(() => {
    if (!active) return;
    pulse.value = 0;
    pulse.value = withRepeat(withTiming(1, { duration: 700, easing: Easing.inOut(Easing.quad) }), -1, true);
  }, [active, pulse]);

  const dotStyle = useAnimatedStyle(() => ({
    opacity: interpolate(pulse.value, [0, 1], [0.5, 1]),
  }));

  if (!active) return null;

  if (collapsed) {
    return (
      <CollapsedBubble
        pulse={pulse}
        pointsCount={points.length}
        onExpand={() => setCollapsed(false)}
      />
    );
  }

  return (
    <Animated.View
      entering={FadeIn.duration(180)}
      exiting={FadeOut.duration(150)}
      style={[
        {
          position: 'absolute',
          right: 22,
          bottom: 22,
          width: 400,
          backgroundColor: tokens.bgRaised,
          borderWidth: 1,
          borderColor: tokens.border,
          borderRadius: 12,
          overflow: 'hidden',
          zIndex: 200,
          boxShadow: '0 22px 50px rgba(0,0,0,0.7), 0 0 0 1px rgba(239,68,68,0.25)',
        } as any,
        dragStyle,
      ]}
    >
      <GestureDetector gesture={panGesture}>
        <Animated.View
          style={
            {
              flexDirection: 'row',
              alignItems: 'center',
              paddingVertical: 10,
              paddingHorizontal: 14,
              borderBottomWidth: 1,
              borderBottomColor: tokens.borderSoft,
              backgroundColor: tokens.bgSubtle,
              gap: 10,
              cursor: 'grab',
            } as any
          }
        >
          <GripDots />
          <Animated.View
            style={[{ width: 8, height: 8, borderRadius: 4, backgroundColor: tokens.live }, dotStyle]}
          />
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', letterSpacing: 1.8, color: tokens.live }}>
            LIVE
          </Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.4 }}>
            · AGENT
          </Text>
          <View style={{ flex: 1 }} />
          <Pressable onPress={() => setCollapsed(true)} hitSlop={4} style={{ padding: 4 }}>
            <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
              <Path d="M5 18h14" stroke={tokens.textMuted} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          </Pressable>
          <Pressable onPress={onExpand} hitSlop={4} style={{ padding: 4 }}>
            <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
              <Path
                d="M4 4h7M4 4v7M20 20h-7M20 20v-7"
                stroke={tokens.textMuted}
                strokeWidth={1.8}
                strokeLinecap="round"
              />
            </Svg>
          </Pressable>
          <Pressable onPress={hidePiP} hitSlop={4} style={{ padding: 4 }}>
            <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
              <Path d="M6 6l12 12M18 6l-12 12" stroke={tokens.textMuted} strokeWidth={1.7} strokeLinecap="round" />
            </Svg>
          </Pressable>
        </Animated.View>
      </GestureDetector>

      <ScrollView
        style={{ height: 280 }}
        contentContainerStyle={{ paddingVertical: 10, paddingHorizontal: 12, gap: 8 }}
        showsVerticalScrollIndicator
      >
        {points.length === 0 ? (
          <Text style={{ fontFamily: FONT_MONO, fontSize: 12, color: tokens.textMuted, fontStyle: 'italic', padding: 6 }}>
            Listening… waiting for the first surface.
          </Text>
        ) : (
          points.map((p, i) => {
            const prominent = i === 0;
            return (
              <Animated.View
                key={p.id}
                entering={FadeIn.duration(240)}
                exiting={FadeOut.duration(160)}
                layout={Layout.springify().damping(16)}
              >
                <Pressable onPress={onExpand}>
                  <View
                    style={{
                      paddingVertical: 10,
                      paddingHorizontal: 10,
                      borderRadius: 5,
                      backgroundColor: prominent ? tokens.bgSubtle : 'transparent',
                      borderLeftWidth: 2,
                      borderLeftColor: prominent ? tokens.live : tokens.borderSoft,
                    }}
                  >
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                      <Text
                        style={{
                          fontFamily: FONT_MONO,
                          fontSize: 8,
                          letterSpacing: 1.6,
                          color: prominent ? tokens.live : tokens.textSubtle,
                          fontWeight: '700',
                        }}
                      >
                        ● {p.category?.toUpperCase() ?? 'NOTE'}
                      </Text>
                      {p.source && (
                        <Text
                          style={{ fontFamily: FONT_MONO, fontSize: 8, letterSpacing: 1.2, color: tokens.textSubtle }}
                        >
                          · {p.source}
                        </Text>
                      )}
                    </View>
                    <Text
                      style={{
                        fontFamily: FONT_MONO,
                        fontSize: prominent ? 13 : 12,
                        color: prominent ? tokens.text : tokens.textMuted,
                        lineHeight: prominent ? 18 : 16,
                      }}
                      numberOfLines={prominent ? undefined : 3}
                    >
                      {p.text}
                    </Text>
                  </View>
                </Pressable>
              </Animated.View>
            );
          })
        )}
      </ScrollView>

      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          paddingVertical: 10,
          paddingHorizontal: 14,
          borderTopWidth: 1,
          borderTopColor: tokens.borderSoft,
          backgroundColor: tokens.bgSubtle,
          gap: 8,
        }}
      >
        <MiniWaveform />
        <View style={{ flex: 1 }} />
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 1.3 }}>
          {points.length} POINT{points.length === 1 ? '' : 'S'} · TAP TO OPEN
        </Text>
      </View>
    </Animated.View>
  );
}

// Collapsed bubble — Gesture.Pan for drag, Tap for expand, runs on UI thread.
function CollapsedBubble({
  pulse,
  pointsCount,
  onExpand,
}: {
  pulse: ReturnType<typeof useSharedValue<number>>;
  pointsCount: number;
  onExpand: () => void;
}) {
  const x = useSharedValue(0);
  const y = useSharedValue(0);

  const posStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: x.value }, { translateY: y.value }],
  }));

  const ringStyle = useAnimatedStyle(() => ({
    opacity: interpolate(pulse.value, [0, 1], [0.5, 0]),
    transform: [{ scale: interpolate(pulse.value, [0, 1], [1, 1.25]) }],
  }));

  const pan = Gesture.Pan()
    .activeOffsetX([-3, 3])
    .activeOffsetY([-3, 3])
    .onChange((e) => {
      x.value += e.changeX;
      y.value += e.changeY;
    })
    .onEnd((e) => {
      x.value = withDecay({ velocity: e.velocityX, clamp: [-600, 600] });
      y.value = withDecay({ velocity: e.velocityY, clamp: [-400, 400] });
    });

  const tap = Gesture.Tap().onEnd(() => {
    runOnJS(onExpand)();
  });

  const composed = Gesture.Exclusive(pan, tap);

  return (
    <Animated.View
      style={[
        {
          position: 'absolute',
          right: 28,
          bottom: 28,
          zIndex: 200,
        },
        posStyle,
      ]}
    >
      <GestureDetector gesture={composed}>
        <Animated.View
          style={
            {
              width: 72,
              height: 72,
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'grab',
              userSelect: 'none',
            } as any
          }
        >
          <Animated.View
            style={[
              {
                position: 'absolute',
                width: 72,
                height: 72,
                borderRadius: 36,
                backgroundColor: tokens.live,
              },
              ringStyle,
            ]}
          />
          <View
            style={
              {
                width: 60,
                height: 60,
                borderRadius: 30,
                backgroundColor: tokens.live,
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: '0 10px 26px rgba(239,68,68,0.55), 0 0 0 1px rgba(255,255,255,0.08)',
              } as any
            }
          >
            <Svg width={26} height={26} viewBox="0 0 24 24" fill="none">
              <Rect x={9} y={2} width={6} height={12} rx={3} stroke="#fff" strokeWidth={2} />
              <Path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" stroke="#fff" strokeWidth={2} strokeLinecap="round" />
            </Svg>
          </View>
          {pointsCount > 0 && (
            <View
              style={{
                position: 'absolute',
                top: -4,
                right: -4,
                minWidth: 22,
                height: 22,
                paddingHorizontal: 6,
                borderRadius: 11,
                backgroundColor: tokens.bgRaised,
                borderWidth: 2,
                borderColor: tokens.live,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Text style={{ fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text, letterSpacing: 0.2 }}>
                {pointsCount}
              </Text>
            </View>
          )}
        </Animated.View>
      </GestureDetector>
    </Animated.View>
  );
}

function GripDots() {
  return (
    <Svg width={12} height={16} viewBox="0 0 12 16">
      {[0, 1, 2].map((row) => (
        <React.Fragment key={row}>
          <Rect x={2} y={3 + row * 4} width={2} height={2} rx={1} fill={tokens.textSubtle} />
          <Rect x={8} y={3 + row * 4} width={2} height={2} rx={1} fill={tokens.textSubtle} />
        </React.Fragment>
      ))}
    </Svg>
  );
}

function MiniWaveform() {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 2, height: 16 }}>
      {[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map((i) => (
        <WaveBar key={i} index={i} />
      ))}
    </View>
  );
}

function WaveBar({ index }: { index: number }) {
  const v = useSharedValue(0.3);
  React.useEffect(() => {
    v.value = withRepeat(
      withTiming(1, { duration: 350 + index * 30, easing: Easing.inOut(Easing.quad) }),
      -1,
      true,
    );
  }, [v, index]);
  const style = useAnimatedStyle(() => ({
    transform: [{ scaleY: v.value }],
  }));
  return (
    <Animated.View
      style={[
        {
          width: 2,
          height: 14,
          borderRadius: 1,
          backgroundColor: tokens.live,
          opacity: 0.75,
        },
        style,
      ]}
    />
  );
}
