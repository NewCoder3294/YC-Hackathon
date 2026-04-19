import React, { useEffect, useRef, useState } from 'react';
import { Pressable, Text, View, ScrollView } from 'react-native';
import { Orchestrator } from '../pipeline/orchestrator';
import { ContinuousCapture } from '../audio/continuous';
import { PressToTalkRecorder } from '../audio/pressToTalk';
import { useEventBus } from '../state/eventBus';
import { FONT_MONO, tokens } from '../../theme/tokens';

export function DevToolsOverlay({ onClose }: { onClose: () => void }) {
  const orchRef    = useRef(new Orchestrator());
  const captureRef = useRef<ContinuousCapture | null>(null);
  const pttRef     = useRef(new PressToTalkRecorder());
  const [running, setRunning] = useState(false);
  const events = useEventBus((s) => s.events.slice(-20));

  useEffect(() => () => { captureRef.current?.stop(); }, []);

  const startContinuous = async () => {
    if (running) return;
    setRunning(true);
    captureRef.current = new ContinuousCapture();
    await captureRef.current.start((chunk) => orchRef.current.processAutonomousChunk(chunk));
  };

  const stopContinuous = async () => {
    await captureRef.current?.stop();
    captureRef.current = null;
    setRunning(false);
  };

  const onPTTStart = () => pttRef.current.start(() => { void onPTTStop(); });
  const onPTTStop  = async () => {
    const audio = await pttRef.current.stop();
    if (audio) orchRef.current.processPressToTalk(audio);
  };

  return (
    <View style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 360, backgroundColor: tokens.bgRaised, borderLeftWidth: 1, borderLeftColor: tokens.border, padding: 12 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 2 }}>VOICE DEVTOOLS</Text>
        <Pressable onPress={onClose} hitSlop={8}><Text style={{ fontFamily: FONT_MONO, color: tokens.textMuted }}>✕</Text></Pressable>
      </View>

      <View style={{ flexDirection: 'row', gap: 8, marginBottom: 12 }}>
        {!running ? (
          <Pressable onPress={startContinuous} style={btnStyle}>
            <Text style={btnLabel}>START LISTEN</Text>
          </Pressable>
        ) : (
          <Pressable onPress={stopContinuous} style={btnStyle}>
            <Text style={btnLabel}>STOP</Text>
          </Pressable>
        )}
        <Pressable onPressIn={onPTTStart} onPressOut={onPTTStop} style={btnStyle}>
          <Text style={btnLabel}>HOLD: PTT</Text>
        </Pressable>
      </View>

      <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.8, marginBottom: 6 }}>LAST 20 EVENTS</Text>
      <ScrollView style={{ flex: 1 }}>
        {events.map((e, i) => (
          <View key={i} style={{ paddingVertical: 4, borderBottomWidth: 1, borderBottomColor: tokens.borderSoft }}>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.5 }}>{e.type.toUpperCase()}</Text>
            <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.text, marginTop: 2 }}>{JSON.stringify(e).slice(0, 200)}</Text>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const btnStyle = { paddingVertical: 8, paddingHorizontal: 12, borderWidth: 1, borderColor: tokens.border, borderRadius: 4, backgroundColor: tokens.bgSubtle, flex: 1, alignItems: 'center' } as const;
const btnLabel = { fontFamily: FONT_MONO, fontSize: 10, fontWeight: '700', color: tokens.text, letterSpacing: 1.5 } as const;
