export type Signature = { event_type: string; players: string[] };

type Options = {
  signatureWindowMs: number;
  transcriptWindowMs: number;
};

type SigRecord = { key: string; at: number };
type TxRecord  = { text: string; at: number };

export class Dedupe {
  private sigs: SigRecord[] = [];
  private txs: TxRecord[] = [];

  constructor(private opts: Options) {}

  ingestTranscript(text: string, now: number) {
    this.txs.push({ text: normalize(text), at: now });
    this.prune(now);
  }

  shouldDrop({ signature, statText, now }: { signature: Signature; statText: string; now: number }): boolean {
    this.prune(now);
    const key = sigKey(signature);
    if (this.sigs.some((r) => r.key === key)) return true;

    const normalized = normalize(statText);
    const overlap = this.txs.some((r) => transcriptOverlap(r.text, normalized) >= 0.6);
    if (overlap) return true;

    this.sigs.push({ key, at: now });
    return false;
  }

  private prune(now: number) {
    this.sigs = this.sigs.filter((r) => now - r.at <= this.opts.signatureWindowMs);
    this.txs  = this.txs.filter((r) => now - r.at <= this.opts.transcriptWindowMs);
  }
}

function sigKey(s: Signature): string {
  return `${s.event_type}::${[...s.players].sort().join(',')}`;
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
}

// Token overlap ratio — simple and fast, good enough for dup suppression.
function transcriptOverlap(a: string, b: string): number {
  const ta = new Set(a.split(' ').filter((w) => w.length > 3));
  const tb = new Set(b.split(' ').filter((w) => w.length > 3));
  if (!tb.size) return 0;
  let hit = 0;
  for (const w of tb) if (ta.has(w)) hit++;
  return hit / tb.size;
}
