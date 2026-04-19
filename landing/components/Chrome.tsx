import { LogoMark } from "./LogoMark";

export function SectionLabel({
  children,
  accent = "default",
}: {
  children: React.ReactNode;
  accent?: "default" | "live" | "verified" | "routing" | "esoteric";
}) {
  const color =
    accent === "live"
      ? "text-live"
      : accent === "verified"
      ? "text-verified"
      : accent === "routing"
      ? "text-routing"
      : accent === "esoteric"
      ? "text-esoteric"
      : "text-text-subtle";
  return (
    <div className={`tracked-wide text-[10px] font-bold uppercase ${color}`}>
      {children}
    </div>
  );
}

export function LivePill({ label = "LIVE" }: { label?: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-[4px] border border-live/70 bg-live/10 px-2 py-1 text-[10px] font-semibold tracked-wide text-live">
      <span className="inline-block h-1.5 w-1.5 rounded-full bg-live" />
      {label}
    </span>
  );
}

export function TopBar() {
  return (
    <header className="sticky top-0 z-30 border-b border-border-soft bg-bg/80 backdrop-blur">
      <div className="mx-auto flex max-w-[1400px] items-center justify-between px-6 py-3.5">
        <div className="flex items-center gap-2.5">
          <LogoMark size={28} />
          <div className="leading-tight">
            <div className="text-[10px] font-bold tracked-wide">BROADCAST</div>
            <div className="text-[10px] font-bold tracked-wide">BRAIN</div>
          </div>
        </div>
        <div className="hidden items-center gap-5 md:flex">
          <nav className="flex items-center gap-5 text-[11px] text-text-muted">
            <a href="#problem" className="hover:text-text">Problem</a>
            <a href="#product" className="hover:text-text">Product</a>
            <a href="#architecture" className="hover:text-text">Architecture</a>
            <a href="#why" className="hover:text-text">Why we win</a>
          </nav>
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 rounded border border-verified/40 bg-verified/10 px-2 py-1 text-[9px] font-semibold tracked-wide text-verified">
              <span className="h-1.5 w-1.5 rounded-full bg-verified" />
              GEMMA 4 · ON CACTUS
            </span>
            <span className="inline-flex items-center gap-1.5 rounded border border-border px-2 py-1 text-[9px] font-semibold tracked-wide text-text-muted">
              YC S26 · VOICE AGENTS
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}

export function FooterBar() {
  return (
    <footer className="mt-auto border-t border-border-soft bg-bg-raised">
      <div className="mx-auto flex max-w-[1400px] flex-col gap-4 px-6 py-8 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-2.5">
          <LogoMark size={24} />
          <div className="text-[10px] tracked-wide text-text-subtle">
            BROADCASTBRAIN · YC VOICE AGENTS HACKATHON 2026
          </div>
        </div>
        <div className="text-[10px] tracked-wide text-text-subtle">
          BUILT WITH GEMMA 4 ON CACTUS · ON-DEVICE · AIRPLANE-MODE SAFE
        </div>
      </div>
    </footer>
  );
}
