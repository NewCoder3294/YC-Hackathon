import React from 'react';
import { Text, View } from 'react-native';
import { FONT_MONO, tokens } from '../theme/tokens';

// Sticky note — yellow, rotated, handwritten font. Commentator's own note.
export function StickyAnnotation({ text }: { text: string }) {
  return (
    <View
      style={{
        marginTop: 10,
        backgroundColor: tokens.stickyBg,
        paddingVertical: 10,
        paddingHorizontal: 12,
        borderRadius: 2,
        // rotation + shadow (web supports both; native rotation is fine, shadow via boxShadow)
        transform: [{ rotate: '-1.2deg' }],
        boxShadow: '0 2px 6px rgba(0,0,0,0.35)',
      }}
    >
      {/* tape */}
      <View
        style={{
          position: 'absolute',
          top: -4,
          left: 10,
          width: 22,
          height: 8,
          backgroundColor: 'rgba(0,0,0,0.18)',
          borderRadius: 1,
        }}
      />
      <Text
        style={{
          fontFamily: FONT_MONO,
          fontSize: 8,
          fontWeight: '700',
          letterSpacing: 1.8,
          color: 'rgba(61,45,10,0.65)',
          marginBottom: 4,
        }}
      >
        MY NOTE
      </Text>
      <Text
        style={{
          // Handwritten fallback stack — browser will pick the first available
          fontFamily: 'Marker Felt, Comic Sans MS, cursive',
          fontSize: 12,
          lineHeight: 16,
          color: tokens.stickyText,
        }}
      >
        {text}
      </Text>
    </View>
  );
}
