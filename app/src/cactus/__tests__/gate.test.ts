import { Gate, VadStats } from '../pipeline/gate';

const loud: VadStats  = { peakDb: -20, voicedFrames: 16, totalFrames: 20 };
const quiet: VadStats = { peakDb: -55, voicedFrames:  0, totalFrames: 20 };

describe('Gate.vadAccept', () => {
  it('accepts loud, voiced audio', () => {
    expect(new Gate().vadAccept(loud)).toBe(true);
  });
  it('rejects silent audio', () => {
    expect(new Gate().vadAccept(quiet)).toBe(false);
  });
  it('rejects audio that is loud but not voiced enough', () => {
    expect(new Gate().vadAccept({ peakDb: -20, voicedFrames: 3, totalFrames: 20 })).toBe(false);
  });
});

describe('Gate.classify', () => {
  it('returns opportunity=true for a goal classification', async () => {
    const gate = new Gate();
    const classifier = jest.fn().mockResolvedValue({
      transcript: 'messi scores from the spot',
      stat_opportunity: true,
      event_type: 'goal',
      players_mentioned: ['messi'],
      score_state_changed: true,
    });
    const r = await gate.classify(new ArrayBuffer(0), classifier);
    expect(r.stat_opportunity).toBe(true);
    expect(r.event_type).toBe('goal');
  });

  it('treats malformed classifier output as drop-worthy', async () => {
    const gate = new Gate();
    const classifier = jest.fn().mockResolvedValue({ garbage: true });
    const r = await gate.classify(new ArrayBuffer(0), classifier);
    expect(r.stat_opportunity).toBe(false);
  });
});
