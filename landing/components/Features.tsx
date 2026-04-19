import { SectionLabel } from "./Chrome";

export function Features() {
  return (
    <section id="product" className="relative border-b border-border-soft">
      <div className="mx-auto max-w-[1400px] px-6 py-24">
        <div className="max-w-[60ch]">
          <SectionLabel>THE PRODUCT</SectionLabel>
          <h2 className="mt-5 font-display text-5xl italic leading-[1.02] text-text">
            Two surfaces. <span className="not-italic font-normal text-text-muted">One broadcast brain.</span>
          </h2>
          <p className="mt-5 max-w-[58ch] text-[14px] leading-[1.65] text-text-muted">
            The pre-match board auto-builds itself overnight from stats APIs,
            formatted exactly how a broadcaster would lay it out. In the booth,
            the live co-pilot listens and surfaces the stat the instant it
            matters — with a tap to ask anything.
          </p>
        </div>

        <div className="mt-14 grid grid-cols-1 gap-6 lg:grid-cols-2">
          <FeatureCard
            number="01"
            title="Pre-match auto spotting board"
            body="Overnight at T-12h, BroadcastBrain ingests squads, tournament stats, match history, injuries, and news from Sportradar — then Gemma 4 writes the storylines, head-to-heads, and matchup notes. Opens offline. Works in airplane mode from load onward."
            preview="/assets/product/spotting-board-preview.svg"
            tag="FEATURE 01"
            accent="verified"
          />
          <FeatureCard
            number="02"
            title="Live co-pilot"
            body="The booth device listens. Gemma 4 on Cactus takes audio natively, decides which stat to surface, and the card lands in under a second. Ask anything by voice — career splits, head-to-head, streaks — and get a sourced answer instantly."
            preview="/assets/product/live-dashboard-mockup.svg"
            tag="FEATURE 02"
            accent="live"
          />
        </div>
      </div>
    </section>
  );
}

function FeatureCard({
  number,
  title,
  body,
  preview,
  tag,
  accent,
}: {
  number: string;
  title: string;
  body: string;
  preview: string;
  tag: string;
  accent: "verified" | "live";
}) {
  const border =
    accent === "verified" ? "border-verified/30" : "border-live/30";
  const tagColor = accent === "verified" ? "text-verified" : "text-live";
  return (
    <article
      className={`group relative overflow-hidden rounded-[8px] border ${border} bg-bg-raised transition-colors hover:border-text/30`}
    >
      <div className="relative aspect-[16/10] w-full overflow-hidden border-b border-border-soft bg-bg">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={preview}
          alt={title}
          className="absolute inset-0 h-full w-full object-cover object-top opacity-90"
        />
        <div className="absolute left-4 top-4">
          <span className={`rounded border border-current/30 bg-bg/70 px-2 py-1 text-[9px] font-semibold tracked-wide backdrop-blur ${tagColor}`}>
            {tag}
          </span>
        </div>
      </div>
      <div className="p-6">
        <div className="flex items-baseline gap-3">
          <span className="text-[11px] tracked-wide text-text-subtle">{number}</span>
          <h3 className="text-[20px] font-semibold text-text">{title}</h3>
        </div>
        <p className="mt-3 text-[13px] leading-[1.65] text-text-muted">{body}</p>
      </div>
    </article>
  );
}
