import { SectionLabel } from "./Chrome";

const QUOTES: {
  who: string;
  role: string;
  org: string;
  quote: string;
}[] = [
  {
    who: "Bob Heussler",
    role: "Radio broadcaster",
    org: "Brooklyn Nets",
    quote:
      "I spend hours building detailed handwritten charts, numerical charts, and storyline outlines for every player.",
  },
  {
    who: "Pat McCarthy",
    role: "TV broadcaster",
    org: "New York Mets",
    quote:
      "Broadcasters can view on tablet in booth. It's my primary surface — not a phone.",
  },
  {
    who: "Rich Ackerman",
    role: "Radio broadcaster",
    org: "CBS Sports Radio",
    quote:
      "I strongly believe in conducting my own research and creating my own spotting boards.",
  },
  {
    who: "Trey Redfield",
    role: "Multi-sport broadcaster",
    org: "Local markets",
    quote:
      "Broadcasters only use about 25% of their notes — the rest is wasted.",
  },
];

export function ValidatedProblem() {
  return (
    <section id="problem" className="relative border-b border-border-soft">
      <div className="mx-auto max-w-[1400px] px-6 py-24">
        <div className="grid grid-cols-1 gap-14 lg:grid-cols-[1.1fr_1.4fr]">
          {/* LEFT — the stat */}
          <div>
            <SectionLabel>THE PROBLEM · VALIDATED</SectionLabel>
            <div className="mt-5 flex items-baseline gap-6">
              <div className="text-[140px] leading-none font-semibold tabular-nums text-text">
                25%
              </div>
            </div>
            <h2 className="mt-2 max-w-[22ch] font-display text-4xl italic leading-[1.05] text-text">
              of a broadcaster&apos;s prep actually gets used on air.
            </h2>
            <p className="mt-6 max-w-[52ch] text-[14px] leading-[1.7] text-text-muted">
              The other 75% is hand-built spotting boards, numerical charts, and
              storyline outlines the commentator can&apos;t scan fast enough
              during a live moment. We talked to working broadcasters across MLB,
              NBA, and hockey. The pattern held every time.
            </p>
            <div className="mt-8 flex flex-wrap gap-2 text-[10px] tracked-wide text-text-subtle">
              <StatPill>HOURS OF PREP</StatPill>
              <StatPill>PAPER-SIZED CHARTS</StatPill>
              <StatPill>ACCURACY PARANOIA</StatPill>
              <StatPill>VISUAL-FIRST · NON-INTRUSIVE</StatPill>
            </div>
          </div>

          {/* RIGHT — quote grid */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {QUOTES.map((q) => (
              <QuoteCard key={q.who} {...q} />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function QuoteCard({
  who,
  role,
  org,
  quote,
}: {
  who: string;
  role: string;
  org: string;
  quote: string;
}) {
  return (
    <figure className="relative flex h-full flex-col justify-between rounded-[6px] border border-border-soft bg-bg-raised p-5">
      <svg
        className="absolute right-3 top-3 opacity-30"
        width="14"
        height="12"
        viewBox="0 0 14 12"
        fill="none"
        aria-hidden
      >
        <path
          d="M0 0h5v4L3 12H0l2-8H0V0zm9 0h5v4l-2 8H9l2-8H9V0z"
          fill="#EF4444"
        />
      </svg>
      <blockquote className="text-[13px] leading-[1.55] text-text">
        &ldquo;{quote}&rdquo;
      </blockquote>
      <figcaption className="mt-5 border-t border-border-soft pt-3">
        <div className="text-[11px] font-semibold text-text">{who}</div>
        <div className="text-[10px] tracked-wide text-text-subtle">
          {role.toUpperCase()} · {org.toUpperCase()}
        </div>
      </figcaption>
    </figure>
  );
}

function StatPill({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded border border-border-soft bg-bg-raised px-2.5 py-1 text-[9px] font-semibold">
      {children}
    </span>
  );
}
