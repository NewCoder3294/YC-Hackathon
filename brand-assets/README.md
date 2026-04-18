# BroadcastBrain — Asset System

Royalty-free SVG asset pack for BroadcastBrain. Dark cinematic aesthetic, broadcast-booth mood, drop-in ready for Next.js / React / Swift.

**Hackathon:** YC Voice Agents Hackathon 2026 (Cactus × Gemma 4)

---

## Design Tokens

```css
/* Surfaces */
--bg-base:     #050505;  /* page background */
--bg-raised:   #0A0A0A;  /* cards, panels */
--bg-subtle:   #141414;  /* nested elements */
--bg-hover:    #171717;  /* chips, hover states */

/* Borders */
--border:      #262626;
--border-soft: #1A1A1A;

/* Text */
--text:        #FAFAFA;  /* primary */
--text-muted:  #A3A3A3;  /* labels, metadata */
--text-subtle: #737373;  /* timestamps, sources */

/* Status */
--live:        #EF4444;  /* live indicators, primary accent */
--verified:    #10B981;  /* Sportradar source badges */
--esoteric:    #F59E0B;  /* disruptor/esoteric metrics */

/* Type */
--font-mono: 'IBM Plex Mono', 'JetBrains Mono', ui-monospace, monospace;
```

Everything in this pack is hard-coded to these values. If you need to theme, open the SVG and swap — or use the `currentColor` icons (see below).

---

## Folder Structure

```
assets/
├── logo/
│   ├── logo-mark.svg           # 64×64 square mark, app icon candidate
│   └── logo-wordmark.svg       # 320×48 horizontal lockup
│
├── icons/                      # 24×24, stroke-based, currentColor
│   ├── icon-mic.svg            # Broadcast microphone
│   ├── icon-headset.svg        # Over-ear headset + boom mic
│   ├── icon-waveform.svg       # Static waveform bars (fill)
│   ├── icon-waveform-live.svg  # ANIMATED — pulsing bars, listening state
│   ├── icon-signal.svg         # Radio waves emanating
│   ├── icon-live.svg           # ANIMATED — LIVE pill with pulse
│   ├── icon-verified.svg       # Sportradar source check (green)
│   ├── icon-esoteric.svg       # Lightning bolt for disruptor metrics
│   ├── icon-replay.svg         # Replay cue arrow
│   ├── icon-flag.svg           # Viral clip flag
│   └── icon-timer.svg          # Latency / stopwatch
│
├── ui/
│   ├── voice-query-button.svg  # 80×80, animated pulse ring, "Hey Brain" CTA
│   └── stat-card-template.svg  # 360×140, reference layout for live stat cards
│
└── backgrounds/
    ├── hero-stadium-gradient.svg   # 1600×900, atmospheric hero
    ├── bg-data-grid.svg            # 400×400, tile-able monospace grid
    ├── bg-noise.svg                # 200×200, film grain overlay (turbulence filter)
    └── og-banner.svg               # 1200×630, social share card
```

---

## Usage in Next.js / React

### Icons (recolorable)

Icons use `stroke="currentColor"` or `fill="currentColor"`. Inline them as React components for maximum control:

```tsx
// components/icons/MicIcon.tsx
export function MicIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
         strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"
         className={className}>
      <rect x="9" y="2" width="6" height="12" rx="3" />
      <path d="M5 10v1a7 7 0 0 0 14 0v-1" />
      <path d="M12 18v4" />
      <path d="M8 22h8" />
    </svg>
  );
}

// usage
<MicIcon className="h-5 w-5 text-neutral-50" />
<MicIcon className="h-5 w-5 text-red-500" />
```

Or import as an `<img>` / Next.js `Image`:

```tsx
import Image from "next/image";
import micIcon from "@/assets/icons/icon-mic.svg";

<Image src={micIcon} alt="" className="h-5 w-5" />
```

### Animated SVGs (live, waveform-live, voice-query-button)

The animated SVGs carry their own `<style>` blocks with `@keyframes`. They only animate when rendered inline in the DOM — **not** as `<img src>`.

```tsx
// components/LiveIndicator.tsx
export function LiveIndicator() {
  return (
    <div
      className="inline-block"
      dangerouslySetInnerHTML={{
        __html: `<svg>...paste contents of icon-live.svg...</svg>`
      }}
    />
  );
}
```

Cleaner pattern — use `@svgr/webpack` or Vite's `?react` import to bring them in as components and the animations survive the import.

### Backgrounds

```tsx
// Hero section
<section className="relative min-h-screen">
  <div className="absolute inset-0 -z-10"
       style={{ backgroundImage: `url(/assets/backgrounds/hero-stadium-gradient.svg)`,
                backgroundSize: "cover" }} />
  <div className="absolute inset-0 -z-10 opacity-60 mix-blend-overlay"
       style={{ backgroundImage: `url(/assets/backgrounds/bg-noise.svg)` }} />
  {/* content */}
</section>
```

The grid pattern tiles — drop it as `background-repeat: repeat` for dashboard surfaces.

---

## OG / Social

Next.js `app/layout.tsx`:

```tsx
export const metadata = {
  title: "BroadcastBrain",
  description: "The spotter that never sleeps. Right stat. Right moment. Under 200ms.",
  openGraph: {
    images: ["/assets/backgrounds/og-banner.svg"],
  },
};
```

Note: some platforms (Slack, iMessage) prefer PNG for OG. If you need to flatten, run:
```bash
npx svg2png-cli og-banner.svg og-banner.png --width 1200 --height 630
```

---

## Stat Card — Live Reference

The `stat-card-template.svg` is a visual spec, not a component. Build the React version using its proportions:

```tsx
<div className="relative rounded-lg border border-neutral-800 bg-neutral-950 p-5">
  <div className="flex items-center justify-between font-mono text-[10px] tracking-widest uppercase">
    <div className="flex items-center gap-2 text-neutral-400">
      <span className="h-2 w-2 rounded-full bg-red-500" />
      LIVE • Q3 8:42
    </div>
    <span className="text-neutral-500">142ms</span>
  </div>

  <div className="mt-4 font-mono text-xs tracking-wider text-neutral-500">
    PATRICK MAHOMES
  </div>
  <div className="mt-1 font-mono text-xl font-bold text-neutral-50">
    12 TDs, 0 INTs in December
  </div>

  <div className="mt-4 flex items-center gap-1.5 font-mono text-[10px] text-emerald-500">
    <VerifiedIcon className="h-3 w-3" /> Sportradar
  </div>
</div>
```

---

## Swift / iOS

For the on-device Cactus app, drop SVGs into `Assets.xcassets` as **Vector Image Sets** (Xcode 12+):

1. Drag each `.svg` into `Assets.xcassets`
2. Select the asset → Inspector → **Preserve Vector Data** = ✓, **Scales** = Single Scale
3. Reference:
```swift
Image("icon-mic")
  .renderingMode(.template)
  .foregroundStyle(.white)
```

The animated SVGs won't render animated in UIKit/SwiftUI via `Image`. Either:
- Convert to Lottie (export keyframes via After Effects / LottieFiles)
- Rebuild the animation in SwiftUI with `withAnimation` (trivial for the LIVE pulse and waveform)

---

## Not Included (and why)

- **Team logos, player photos, league marks** — licensing risk. For the demo, use generic silhouettes or roster initials.
- **Stock broadcaster photography** — search results returned editorial/rights-managed content. If you need people/booth shots for the deck, grab from Unsplash with attribution.
- **Raster hero images** — all backgrounds here are SVG so they scale perfectly on retina / projector for the demo. If you want a real stadium photo for the landing hero, source from Unsplash (`stadium night lights`) and run through a dark overlay.

---

## Quick Color / Font Check

**If you change brand colors**, update these files (they have hard-coded hex values):
- `logo-mark.svg`, `logo-wordmark.svg` — the red bar
- `icon-live.svg`, `icon-verified.svg`, `icon-esoteric.svg` — status colors
- `stat-card-template.svg`, `voice-query-button.svg` — all tokens
- `hero-stadium-gradient.svg`, `og-banner.svg` — gradient stops

**If you change the typeface** from IBM Plex Mono, update `logo-wordmark.svg`, `icon-live.svg`, `stat-card-template.svg`, and `og-banner.svg`. Everything else is pure geometry.

---

**Good luck in the demo. Hit the 200ms latency counter on screen — that's the moat.**
