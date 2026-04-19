import { Audio } from 'expo-av';
import type { VadStats } from '../pipeline/gate';

const WINDOW_MS = 2_000;
const HOP_MS    = 1_500;

export type Chunk = { audio: ArrayBuffer; stats: VadStats; at: number };

export class ContinuousCapture {
  private recording: Audio.Recording | null = null;
  private timer: ReturnType<typeof setInterval> | null = null;
  private meterings: { db: number; at: number }[] = [];

  async start(onChunk: (chunk: Chunk) => void): Promise<void> {
    if (this.recording) return;
    const perm = await Audio.requestPermissionsAsync();
    if (!perm.granted) throw new Error('Mic permission denied');
    await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });

    await this.startInner(onChunk);
  }

  private async startInner(onChunk: (chunk: Chunk) => void) {
    const rec = new Audio.Recording();
    await rec.prepareToRecordAsync({
      ...Audio.RecordingOptionsPresets.HIGH_QUALITY,
      isMeteringEnabled: true,
    });
    rec.setOnRecordingStatusUpdate((st) => {
      if (st.isRecording && typeof st.metering === 'number') {
        this.meterings.push({ db: st.metering, at: Date.now() });
      }
    });
    await rec.startAsync();
    this.recording = rec;

    this.timer = setInterval(async () => {
      const chunk = await this.rotate();
      if (!chunk) return;
      onChunk(chunk);
    }, HOP_MS);
  }

  private async rotate(): Promise<Chunk | null> {
    if (!this.recording) return null;
    const old = this.recording;
    const fresh = new Audio.Recording();
    await fresh.prepareToRecordAsync({
      ...Audio.RecordingOptionsPresets.HIGH_QUALITY,
      isMeteringEnabled: true,
    });
    await fresh.startAsync();
    this.recording = fresh;

    await old.stopAndUnloadAsync();
    const uri = old.getURI();
    if (!uri) return null;
    const res = await fetch(uri);
    const audio = await res.arrayBuffer();
    const stats = this.drainMeterings();
    return { audio, stats, at: Date.now() };
  }

  private drainMeterings(): VadStats {
    const now = Date.now();
    const windowStart = now - WINDOW_MS;
    const inWindow = this.meterings.filter((m) => m.at >= windowStart);
    this.meterings = this.meterings.filter((m) => m.at >= now - WINDOW_MS);
    const peakDb = inWindow.reduce((p, m) => Math.max(p, m.db), -160);
    const voicedFrames = inWindow.filter((m) => m.db > -45).length;
    return { peakDb, voicedFrames, totalFrames: Math.max(1, inWindow.length) };
  }

  async stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    if (this.recording) {
      await this.recording.stopAndUnloadAsync();
      this.recording = null;
    }
    this.meterings = [];
  }
}
