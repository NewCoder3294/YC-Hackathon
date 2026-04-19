import { Dedupe } from '../pipeline/dedupe';

describe('Dedupe', () => {
  it('drops exact signature within window', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    const sig = { event_type: 'goal', players: ['messi'] };
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 0 })).toBe(false);
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 5_000 })).toBe(true);
  });

  it('allows signature again after window expires', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    const sig = { event_type: 'goal', players: ['messi'] };
    d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 0 });
    expect(d.shouldDrop({ signature: sig, statText: 'Messi 5th', now: 31_000 })).toBe(false);
  });

  it('drops when commentator already said the stat substring', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    d.ingestTranscript('this is messi fifth goal of the tournament', 1_000);
    const drop = d.shouldDrop({
      signature: { event_type: 'goal', players: ['messi'] },
      statText: 'Messi fifth goal of the tournament',
      now: 2_000,
    });
    expect(drop).toBe(true);
  });

  it('transcript expires outside its window', () => {
    const d = new Dedupe({ signatureWindowMs: 30_000, transcriptWindowMs: 20_000 });
    d.ingestTranscript('messi fifth goal', 0);
    const drop = d.shouldDrop({
      signature: { event_type: 'goal', players: ['messi'] },
      statText: 'Messi fifth goal',
      now: 21_000,
    });
    expect(drop).toBe(false);
  });
});
