import { LivePill, SectionLabel } from "./Chrome";

export function Hero() {
  return (
    <section className="relative overflow-hidden border-b border-border-soft">
      <div className="spotlight scanlines pointer-events-none absolute inset-0" />

      <div className="relative mx-auto grid max-w-[1400px] grid-cols-1 gap-14 px-6 py-20 lg:grid-cols-[1fr_1.15fr] lg:py-28">
        {/* LEFT — copy */}
        <div className="flex flex-col justify-center">
          <div className="mb-6 flex items-center gap-3">
            <SectionLabel accent="live">● LIVE DEMO · AIRPLANE MODE ON</SectionLabel>
          </div>

          <h1 className="text-5xl leading-[0.98] tracked-tight text-text sm:text-6xl lg:text-[68px]">
            <span className="font-display italic text-text">A second pair</span>
            <br />
            <span>of broadcaster eyes.</span>
          </h1>

          <p className="mt-7 max-w-[56ch] text-[15px] leading-[1.65] text-text-muted">
            BroadcastBrain listens to the match, knows every player, and surfaces
            the right stat the instant it&apos;s relevant — all on-device, in under
            a second, airplane-mode safe. Voice-first. Validated with working
            broadcasters at the <span className="text-text">Brooklyn Nets</span>,{" "}
            <span className="text-text">NY Mets</span>, and{" "}
            <span className="text-text">CBS Sports Radio</span>.
          </p>

          <div className="mt-9 grid grid-cols-3 gap-0 divide-x divide-border-soft border-y border-border-soft py-6">
            <StatCell value="<1s" label="P50 LATENCY" accent="live" />
            <StatCell value="100%" label="ON-DEVICE" accent="verified" />
            <StatCell value="4/4" label="BROADCASTERS VALIDATED" accent="routing" />
          </div>

          <div className="mt-8 flex flex-wrap items-center gap-3 text-[10px] tracked-wide text-text-subtle">
            <span className="inline-flex items-center gap-1.5 rounded border border-border-soft bg-bg-raised px-2 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-verified" /> SPORTRADAR-SOURCED
            </span>
            <span className="inline-flex items-center gap-1.5 rounded border border-border-soft bg-bg-raised px-2 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-routing" /> GEMMA 4 E4B · 4.5B
            </span>
            <span className="inline-flex items-center gap-1.5 rounded border border-border-soft bg-bg-raised px-2 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-esoteric" /> APPLE ON-DEVICE STT
            </span>
          </div>
        </div>

        {/* RIGHT — demo video in tablet frame */}
        <div className="relative">
          <div className="relative overflow-hidden rounded-[14px] border border-border bg-bg-raised shadow-[0_40px_120px_-20px_rgba(239,68,68,0.18)]">
            {/* device top bezel row */}
            <div className="flex items-center justify-between border-b border-border-soft bg-bg-subtle/60 px-4 py-2">
              <div className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-full bg-[#3a3a3a]" />
                <span className="h-2.5 w-2.5 rounded-full bg-[#3a3a3a]" />
                <span className="h-2.5 w-2.5 rounded-full bg-[#3a3a3a]" />
              </div>
              <div className="text-[9px] tracked-wide text-text-subtle">
                ARGENTINA vs FRANCE · 2022 WC FINAL · LUSAIL STADIUM
              </div>
              <LivePill />
            </div>

            <video
              className="block h-auto w-full"
              src="/video/demo.mp4"
              autoPlay
              muted
              loop
              playsInline
              preload="metadata"
            />
          </div>

          {/* Floating callouts */}
          <div className="pointer-events-none absolute -left-4 top-1/3 hidden rotate-[-2deg] rounded border border-routing/50 bg-bg-raised/90 px-3 py-2 text-[10px] tracked-wide text-routing shadow-xl backdrop-blur md:block">
            <div className="font-bold">GEMMA 4 · ON-DEVICE</div>
            <div className="text-text-muted">no network during demo</div>
          </div>
          <div className="pointer-events-none absolute -right-3 bottom-8 hidden rotate-[1.5deg] rounded border border-verified/50 bg-bg-raised/90 px-3 py-2 text-[10px] tracked-wide text-verified shadow-xl backdrop-blur md:block">
            <div className="font-bold">SPORTRADAR ✓</div>
            <div className="text-text-muted">every stat sourced</div>
          </div>
        </div>
      </div>
    </section>
  );
}

function StatCell({
  value,
  label,
  accent,
}: {
  value: string;
  label: string;
  accent: "live" | "verified" | "routing";
}) {
  const color =
    accent === "live"
      ? "text-live"
      : accent === "verified"
      ? "text-verified"
      : "text-routing";
  return (
    <div className="px-5 first:pl-0 last:pr-0">
      <div className={`text-3xl font-semibold tabular-nums ${color}`}>{value}</div>
      <div className="mt-1 text-[9px] tracked-wide text-text-subtle">{label}</div>
    </div>
  );
}
