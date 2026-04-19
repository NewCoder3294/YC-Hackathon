import { Audio } from 'expo-av';

const MAX_RECORD_MS = 8_000;

export class PressToTalkRecorder {
  private recording: Audio.Recording | null = null;
  private autoStopTimer: ReturnType<typeof setTimeout> | null = null;

  async start(onAutoStop: () => void): Promise<void> {
    if (this.recording) return;
    const perm = await Audio.requestPermissionsAsync();
    if (!perm.granted) throw new Error('Mic permission denied');
    await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });

    const rec = new Audio.Recording();
    await rec.prepareToRecordAsync(Audio.RecordingOptionsPresets.HIGH_QUALITY);
    await rec.startAsync();
    this.recording = rec;

    this.autoStopTimer = setTimeout(() => {
      onAutoStop();
    }, MAX_RECORD_MS);
  }

  async stop(): Promise<ArrayBuffer | null> {
    if (!this.recording) return null;
    if (this.autoStopTimer) clearTimeout(this.autoStopTimer);
    this.autoStopTimer = null;

    await this.recording.stopAndUnloadAsync();
    const uri = this.recording.getURI();
    this.recording = null;
    if (!uri) return null;
    return uriToArrayBuffer(uri);
  }
}

async function uriToArrayBuffer(uri: string): Promise<ArrayBuffer> {
  const res = await fetch(uri);
  return await res.arrayBuffer();
}
