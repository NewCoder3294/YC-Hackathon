"use client";

import { motion } from "framer-motion";
import { SectionLabel } from "./Chrome";

const STAGES = [
  {
    id: "voice",
    label: "COMMENTATOR",
    sub: "Mic · booth audio",
    chip: "REAL-TIME",
    accent: "live",
    icon: "mic",
  },
  {
    id: "stt",
    label: "APPLE STT",
    sub: "On-device transcription",
    chip: "< 200ms · ON-DEVICE",
    accent: "text",
    icon: "waveform",
  },
  {
    id: "gemma",
    label: "GEMMA 4 · CACTUS",
    sub: "E4B · 4.5B params · tool calls",
    chip: "ON-DEVICE · HYBRID ROUTER",
    accent: "routing",
    icon: "brain",
  },
  {
    id: "tools",
    label: "TOOL CALLS",
    sub: "Sportradar-sourced functions",
    chip: "DETERMINISTIC",
    accent: "esoteric",
    icon: "code",
  },
  {
    id: "card",
    label: "STAT CARD",
    sub: "Rendered in the booth",
    chip: "p50 · < 1s",
    accent: "verified",
    icon: "check",
  },
] as const;

const TOOLS = [
  "get_player_stats",
  "get_head_to_head",
  "get_streak_alerts",
  "get_match_facts",
  "get_lineups",
];

const ACCENT: Record<string, { text: string; border: string; bg: string; stroke: string }> = {
  live:     { text: "text-live",     border: "border-live/40",     bg: "bg-live/10",     stroke: "#EF4444" },
  routing:  { text: "text-routing",  border: "border-routing/50",  bg: "bg-routing/10",  stroke: "#8B5CF6" },
  esoteric: { text: "text-esoteric", border: "border-esoteric/40", bg: "bg-esoteric/10", stroke: "#F59E0B" },
  verified: { text: "text-verified", border: "border-verified/40", bg: "bg-verified/10", stroke: "#10B981" },
  text:     { text: "text-text",     border: "border-border",      bg: "bg-bg-subtle",   stroke: "#FAFAFA" },
};

export function ArchitectureDiagram() {
  return (
    <section id="architecture" className="relative border-b border-border-soft bg-bg-raised">
      <div className="dot-grid pointer-events-none absolute inset-0 opacity-60" />
      <div className="relative mx-auto max-w-[1400px] px-6 py-24">
        {/* Heading */}
        <div className="grid grid-cols-1 gap-10 lg:grid-cols-[1fr_1.2fr] lg:items-end">
          <div>
            <SectionLabel accent="routing">THE ARCHITECTURE</SectionLabel>
            <h2 className="mt-5 font-display text-5xl italic leading-[1.02] text-text">
              Built on-device.{" "}
              <span className="not-italic font-normal text-text-muted">
                End-to-end.
              </span>
            </h2>
          </div>
          <p className="text-[14px] leading-[1.65] text-text-muted">
            Voice to stat card in a single pass — no round-trip to the cloud.
            Apple captures audio, transcribes on-device. Gemma 4 on Cactus decides
            what&apos;s relevant and calls deterministic tools against a
            Sportradar-sourced match cache. The card renders in the booth in under
            a second, airplane-mode-safe from kickoff onward.
          </p>
        </div>

        {/* The diagram */}
        <div className="mt-14 overflow-x-auto">
          <div className="relative mx-auto w-full min-w-[980px] max-w-[1300px]">
            <Pipeline />
          </div>
        </div>

        {/* Ratio + criteria */}
        <div className="mt-16 grid grid-cols-1 gap-6 lg:grid-cols-[1.3fr_1fr]">
          <EdgeCloudRatio />
          <ToolsPanel tools={TOOLS} />
        </div>
      </div>
    </section>
  );
}

function Pipeline() {
  // Layout: 5 stages evenly spaced across 1200px viewBox width, 260 tall
  const W = 1260;
  const H = 300;
  const N = STAGES.length;
  const margin = 40;
  const stageW = 180;
  const gap = (W - margin * 2 - stageW * N) / (N - 1);
  const stageY = (H - 120) / 2;

  const stagePositions = STAGES.map((_, i) => margin + i * (stageW + gap));

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      className="block w-full"
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="flow-line" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#EF4444" stopOpacity="0.4" />
          <stop offset="50%" stopColor="#8B5CF6" stopOpacity="0.9" />
          <stop offset="100%" stopColor="#10B981" stopOpacity="0.6" />
        </linearGradient>
        <filter id="packet-glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      {/* Connecting line — single gradient stroke across all stages */}
      <line
        x1={stagePositions[0] + stageW}
        y1={stageY + 60}
        x2={stagePositions[N - 1]}
        y2={stageY + 60}
        stroke="url(#flow-line)"
        strokeWidth="1.5"
        strokeDasharray="4 6"
      />

      {/* Animated packets — three staggered */}
      {[0, 1.4, 2.8].map((delay, idx) => (
        <AnimatedPacket
          key={idx}
          delay={delay}
          fromX={stagePositions[0] + stageW}
          toX={stagePositions[N - 1]}
          y={stageY + 60}
        />
      ))}

      {/* Stages */}
      {STAGES.map((stage, i) => {
        const accent = ACCENT[stage.accent];
        return (
          <g key={stage.id} transform={`translate(${stagePositions[i]}, ${stageY})`}>
            {/* Chip above stage */}
            <g transform={`translate(${stageW / 2}, -20)`}>
              <rect
                x={-chipWidth(stage.chip) / 2}
                y={-12}
                width={chipWidth(stage.chip)}
                height={18}
                rx={3}
                fill="#0A0A0A"
                stroke={accent.stroke}
                strokeOpacity="0.45"
                strokeWidth="1"
              />
              <text
                x="0"
                y="0"
                textAnchor="middle"
                className="font-mono"
                fontSize="9"
                fontWeight="600"
                fill={accent.stroke}
                letterSpacing="1.2"
              >
                {stage.chip}
              </text>
            </g>

            {/* Stage card */}
            <rect
              width={stageW}
              height={120}
              rx={8}
              fill="#050505"
              stroke={accent.stroke}
              strokeOpacity="0.35"
              strokeWidth="1"
            />
            <rect
              x={0}
              y={0}
              width={stageW}
              height={120}
              rx={8}
              fill={accent.stroke}
              opacity="0.04"
            />
            {/* top left index */}
            <text
              x={14}
              y={22}
              className="font-mono"
              fontSize="10"
              fill="#737373"
              letterSpacing="1.4"
            >
              0{i + 1}
            </text>
            {/* Icon */}
            <g transform={`translate(${stageW - 38}, 12)`}>
              <StageIcon icon={stage.icon} color={accent.stroke} />
            </g>
            {/* Label */}
            <text
              x={14}
              y={60}
              className="font-mono"
              fontSize="13"
              fontWeight="700"
              fill="#FAFAFA"
              letterSpacing="0.5"
            >
              {stage.label}
            </text>
            <text
              x={14}
              y={82}
              className="font-mono"
              fontSize="10"
              fill="#A3A3A3"
            >
              {stage.sub}
            </text>

            {/* port dot */}
            {i < N - 1 && (
              <circle cx={stageW} cy={60} r={3.5} fill={accent.stroke} />
            )}
            {i > 0 && (
              <circle cx={0} cy={60} r={3.5} fill={accent.stroke} />
            )}
          </g>
        );
      })}

      {/* Sportradar cache reference */}
      <g transform={`translate(${stagePositions[3] + stageW / 2 - 90}, ${stageY + 170})`}>
        <line x1="90" y1="-50" x2="90" y2="-10" stroke="#F59E0B" strokeOpacity="0.4" strokeDasharray="2 3" />
        <rect width="180" height="38" rx="5" fill="#0A0A0A" stroke="#F59E0B" strokeOpacity="0.4" />
        <text x="12" y="16" className="font-mono" fontSize="9" fill="#737373" letterSpacing="1.2">
          READS FROM
        </text>
        <text x="12" y="30" className="font-mono" fontSize="11" fontWeight="700" fill="#F59E0B">
          SPORTRADAR MATCH CACHE
        </text>
      </g>

      {/* Cloud fallback branch — subdued */}
      <g transform={`translate(${stagePositions[2] + stageW / 2 - 95}, ${stageY - 90})`}>
        <line x1="95" y1="80" x2="95" y2="50" stroke="#525252" strokeOpacity="0.45" strokeDasharray="2 3" />
        <rect width="190" height="44" rx="5" fill="#0A0A0A" stroke="#404040" />
        <text x="12" y="16" className="font-mono" fontSize="9" fill="#525252" letterSpacing="1.2">
          CLOUD FALLBACK (optional)
        </text>
        <text x="12" y="32" className="font-mono" fontSize="11" fontWeight="700" fill="#A3A3A3">
          GEMINI · only if confidence drops
        </text>
      </g>
    </svg>
  );
}

function chipWidth(text: string) {
  return text.length * 6.2 + 16;
}

function AnimatedPacket({
  delay,
  fromX,
  toX,
  y,
}: {
  delay: number;
  fromX: number;
  toX: number;
  y: number;
}) {
  return (
    <motion.circle
      cx={0}
      cy={y}
      r={5}
      fill="#FAFAFA"
      filter="url(#packet-glow)"
      initial={{ opacity: 0, cx: fromX }}
      animate={{
        cx: [fromX, toX],
        opacity: [0, 1, 1, 0],
      }}
      transition={{
        duration: 4.2,
        delay,
        repeat: Infinity,
        ease: "linear",
        times: [0, 0.05, 0.95, 1],
      }}
    />
  );
}

function StageIcon({ icon, color }: { icon: string; color: string }) {
  const common = {
    stroke: color,
    strokeWidth: 1.6,
    fill: "none",
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  switch (icon) {
    case "mic":
      return (
        <svg width="22" height="22" viewBox="0 0 24 24">
          <rect x="9" y="2" width="6" height="12" rx="3" {...common} />
          <path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" {...common} />
        </svg>
      );
    case "waveform":
      return (
        <svg width="22" height="22" viewBox="0 0 24 24">
          <path d="M3 12h2M7 8v8M11 4v16M15 8v8M19 11v2M21 12h-1" {...common} />
        </svg>
      );
    case "brain":
      return (
        <svg width="22" height="22" viewBox="0 0 24 24">
          <path d="M9 3a3 3 0 0 0-3 3 3 3 0 0 0-2 5 3 3 0 0 0 1 5 3 3 0 0 0 4 4 3 3 0 0 0 6 0 3 3 0 0 0 4-4 3 3 0 0 0 1-5 3 3 0 0 0-2-5 3 3 0 0 0-3-3 3 3 0 0 0-6 0z" {...common} />
          <path d="M12 8v8M9 12h6" {...common} />
        </svg>
      );
    case "code":
      return (
        <svg width="22" height="22" viewBox="0 0 24 24">
          <path d="M8 6l-5 6 5 6M16 6l5 6-5 6M13 3l-2 18" {...common} />
        </svg>
      );
    case "check":
      return (
        <svg width="22" height="22" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9" {...common} />
          <path d="M8 12l3 3 5-6" {...common} />
        </svg>
      );
    default:
      return null;
  }
}

function EdgeCloudRatio() {
  return (
    <div className="rounded-[8px] border border-border-soft bg-bg p-6">
      <SectionLabel accent="verified">EDGE / CLOUD RATIO</SectionLabel>
      <div className="mt-4 flex items-baseline gap-3">
        <div className="text-5xl font-semibold tabular-nums text-verified">97%</div>
        <div className="text-[12px] tracked-wide text-text-subtle">ON-DEVICE</div>
      </div>
      <div className="mt-5 flex h-2 w-full overflow-hidden rounded-full bg-bg-subtle">
        <div className="h-full bg-verified" style={{ width: "97%" }} />
        <div className="h-full bg-esoteric/60" style={{ width: "3%" }} />
      </div>
      <div className="mt-3 flex items-center justify-between text-[10px] tracked-wide text-text-subtle">
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-verified" />
          GEMMA 4 · ON-DEVICE
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-esoteric/60" />
          CLOUD FALLBACK · OPTIONAL
        </span>
      </div>
      <p className="mt-5 text-[12px] leading-[1.65] text-text-muted">
        Every voice-to-card cycle runs fully on the booth device. Cloud is only
        consulted when Gemma&apos;s tool-call confidence drops — and we log
        every escalation for later training.
      </p>
    </div>
  );
}

function ToolsPanel({ tools }: { tools: string[] }) {
  return (
    <div className="rounded-[8px] border border-border-soft bg-bg p-6">
      <SectionLabel accent="esoteric">TOOL CALLS · DETERMINISTIC</SectionLabel>
      <p className="mt-4 text-[12px] leading-[1.65] text-text-muted">
        Gemma doesn&apos;t hallucinate stats. It picks a tool — each backed by
        the Sportradar-sourced match cache — and we render the result verbatim
        with a <span className="text-verified">✓ Sportradar</span> badge.
      </p>
      <ul className="mt-5 grid grid-cols-1 gap-1.5">
        {tools.map((t) => (
          <li
            key={t}
            className="flex items-center justify-between rounded border border-border-soft bg-bg-raised px-3 py-2 text-[11px]"
          >
            <span className="text-text">{t}()</span>
            <span className="text-[9px] tracked-wide text-verified">SOURCED</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
