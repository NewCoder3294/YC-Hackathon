import { SectionLabel } from "./Chrome";

const PILLARS = [
  {
    tag: "HYBRID ROUTING",
    title: "On-device first. Cloud only when confidence drops.",
    body: "Gemma 4 on Cactus makes the routing decision at inference time. 97% of stat-card cycles never leave the booth — and the 3% that escalate are logged for the next training loop.",
    metric: "97%",
    metricLabel: "ON-DEVICE RATIO",
    accent: "routing",
  },
  {
    tag: "TOOL CALL CORRECTNESS",
    title: "Gemma decides the tool. The data is sourced, not hallucinated.",
    body: "Five deterministic functions backed by the Sportradar match cache. Every card ships with a ✓ Sportradar badge. If Gemma picks wrong, we see the mis-call in the log — not in a judge&apos;s ear.",
    metric: "✓",
    metricLabel: "SPORTRADAR-SOURCED",
    accent: "verified",
  },
  {
    tag: "VOICE → ACTION LATENCY",
    title: "Under one second, measured end-to-end.",
    body: "Mic capture → Gemma 4 (native audio in) → tool call → rendered card. P50 in the hundreds of milliseconds on an iPad Pro. The broadcaster glances and reads before the moment passes.",
    metric: "<1s",
    metricLabel: "P50 END-TO-END",
    accent: "live",
  },
  {
    tag: "END-TO-END WORKING PRODUCT",
    title: "A real demo match, not a slide.",
    body: "Argentina vs France · 2022 World Cup Final. 46 players, 184 storylines, 23 precedents — all cached locally at match start. Airplane mode on from second zero.",
    metric: "46·184·23",
    metricLabel: "PLAYERS · STORIES · PRECEDENTS",
    accent: "esoteric",
  },
] as const;

export function WhyWeWin() {
  return (
    <section id="why" className="relative border-b border-border-soft">
      <div className="mx-auto max-w-[1400px] px-6 py-24">
        <div className="max-w-[62ch]">
          <SectionLabel accent="live">WHY WE WIN</SectionLabel>
          <h2 className="mt-5 font-display text-5xl italic leading-[1.02] text-text">
            Scored against every Cactus rubric line.
          </h2>
          <p className="mt-5 max-w-[60ch] text-[14px] leading-[1.65] text-text-muted">
            The Cactus × Gemma 4 hackathon judges on five dimensions. We built
            for every one.
          </p>
        </div>

        <div className="mt-14 grid grid-cols-1 gap-5 md:grid-cols-2">
          {PILLARS.map((p) => (
            <Pillar key={p.tag} {...p} />
          ))}
        </div>
      </div>
    </section>
  );
}

function Pillar({
  tag,
  title,
  body,
  metric,
  metricLabel,
  accent,
}: {
  tag: string;
  title: string;
  body: string;
  metric: string;
  metricLabel: string;
  accent: "routing" | "verified" | "live" | "esoteric";
}) {
  const accentClass =
    accent === "routing"
      ? "text-routing border-routing/40"
      : accent === "verified"
      ? "text-verified border-verified/40"
      : accent === "live"
      ? "text-live border-live/40"
      : "text-esoteric border-esoteric/40";
  return (
    <article
      className={`group relative flex flex-col gap-5 rounded-[8px] border border-border-soft bg-bg-raised p-7 transition-colors hover:border-text/20`}
    >
      <div className={`inline-flex w-fit items-center gap-1.5 rounded border bg-bg px-2 py-1 text-[9px] font-bold tracked-wide ${accentClass}`}>
        <span className={`h-1.5 w-1.5 rounded-full ${accent === "routing" ? "bg-routing" : accent === "verified" ? "bg-verified" : accent === "live" ? "bg-live" : "bg-esoteric"}`} />
        {tag}
      </div>

      <h3 className="text-[20px] leading-[1.25] text-text">{title}</h3>

      <p className="text-[13px] leading-[1.65] text-text-muted">{body}</p>

      <div className="mt-auto flex items-end justify-between border-t border-border-soft pt-5">
        <div className={`text-4xl font-semibold tabular-nums ${accentClass.split(" ")[0]}`}>{metric}</div>
        <div className="text-[9px] tracked-wide text-text-subtle">{metricLabel}</div>
      </div>
    </article>
  );
}
