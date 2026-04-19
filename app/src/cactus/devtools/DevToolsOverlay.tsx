import React, { useEffect, useRef, useState } from 'react';
import { Pressable, Text, View, ScrollView } from 'react-native';
import { Orchestrator } from '../pipeline/orchestrator';
import { ContinuousCapture } from '../audio/continuous';
import { PressToTalkRecorder } from '../audio/pressToTalk';
import { useEventBus } from '../state/eventBus';
import { useModelLoader } from '../state/modelLoader';
import { FONT_MONO, tokens } from '../../theme/tokens';

export function DevToolsOverlay({ onClose }: { onClose: () => void }) {
  const orchRef    = useRef(new Orchestrator());
  const captureRef = useRef<ContinuousCapture | null>(null);
  const pttRef     = useRef(new PressToTalkRecorder());
  const [running, setRunning] = useState(false);
  const [testResult, setTestResult] = useState<string>('');
  const [testLatency, setTestLatency] = useState<number | null>(null);
  const events = useEventBus((s) => s.events.slice(-20));

  const modelStatus  = useModelLoader((s) => s.status);
  const downloadPct  = Math.round(useModelLoader((s) => s.progress) * 100);
  const ensureModel  = useModelLoader((s) => s.ensureLoaded);
  const sharedClient = useModelLoader((s) => s.client);

  useEffect(() => () => { captureRef.current?.stop(); }, []);

  const runTextProbe = async () => {
    setTestResult('');
    setTestLatency(null);
    const ok = await ensureModel();
    if (!ok) {
      setTestResult('model not ready — check status pill');
      return;
    }
    const t0 = Date.now();
    try {
      const out = await sharedClient.complete({
        messages: [
          { role: 'system', content: 'Reply in five words or fewer.' },
          { role: 'user',   content: 'Say hi.' },
        ],
        maxTokens: 32,
        temperature: 0.2,
      });
      setTestLatency(Date.now() - t0);
      setTestResult(out.response.slice(0, 200));
    } catch (err) {
      setTestLatency(Date.now() - t0);
      setTestResult(`error: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  const startContinuous = async () => {
    if (running) return;
    const ok = await ensureModel();
    if (!ok) return;
    setRunning(true);
    captureRef.current = new ContinuousCapture();
    try {
      await captureRef.current.start((chunk) => orchRef.current.processAutonomousChunk(chunk));
    } catch (err) {
      setTestResult(`mic error: ${err instanceof Error ? err.message : String(err)}`);
      setRunning(false);
    }
  };

  const stopContinuous = async () => {
    await captureRef.current?.stop();
    captureRef.current = null;
    setRunning(false);
  };

  const onPTTStart = async () => {
    const ok = await ensureModel();
    if (!ok) return;
    try {
      await pttRef.current.start(() => { void onPTTStop(); });
    } catch (err) {
      setTestResult(`mic error: ${err instanceof Error ? err.message : String(err)}`);
    }
  };
  const onPTTStop = async () => {
    const audio = await pttRef.current.stop();
    if (audio) orchRef.current.processPressToTalk(audio);
  };

  const statusLine =
    modelStatus === 'unloaded'    ? 'MODEL: not loaded — tap TEST TEXT to download (~6.3 GB on first run)' :
    modelStatus === 'downloading' ? `MODEL: downloading ${downloadPct}%` :
    modelStatus === 'loading'     ? 'MODEL: loading' :
    modelStatus === 'ready'       ? 'MODEL: ready' :
                                    `MODEL: error`;
  const statusColor =
    modelStatus === 'ready' ? tokens.verified :
    modelStatus === 'error' ? tokens.live :
                              tokens.textMuted;

  return (
    <View style={{ position: 'absolute', top: 0, right: 0, bottom: 0, width: 360, backgroundColor: tokens.bgRaised, borderLeftWidth: 1, borderLeftColor: tokens.border, padding: 12 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: tokens.textSubtle, letterSpacing: 2 }}>VOICE DEVTOOLS</Text>
        <Pressable onPress={onClose} hitSlop={8}><Text style={{ fontFamily: FONT_MONO, color: tokens.textMuted }}>✕</Text></Pressable>
      </View>

      <View style={{ paddingVertical: 6, paddingHorizontal: 8, backgroundColor: tokens.bgSubtle, borderRadius: 4, marginBottom: 10 }}>
        <Text style={{ fontFamily: FONT_MONO, fontSize: 10, color: statusColor }}>{statusLine}</Text>
      </View>

      <Pressable onPress={runTextProbe} style={[btnStyle, { marginBottom: 8 }]}>
        <Text style={btnLabel}>TEST TEXT (no mic)</Text>
      </Pressable>

      {!!testResult && (
        <View style={{ marginBottom: 12, paddingHorizontal: 8, paddingVertical: 6, backgroundColor: tokens.bgSubtle, borderRadius: 4 }}>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 9, color: tokens.textSubtle, letterSpacing: 1.5, marginBottom: 4 }}>RESPONSE{testLatency !== null ? ` · ${testLatency}ms` : ''}</Text>
          <Text style={{ fontFamily: FONT_MONO, fontSize: 11, color: tokens.text }}>{testResult}</Text>
        </View>
      )}

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
