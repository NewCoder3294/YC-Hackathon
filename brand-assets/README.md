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
--routing:     #8B5CF6;  /* Gemma/routing indicators */

/* Type */
--font-mono: 'IBM Plex Mono', 'JetBrains Mono', ui-monospace, monospace;
```

Everything in this pack is hard-coded to these values. If you need to theme, open the SVG and swap — or use the `currentColor` icons (see below).

---

## Folder Structure

```
brand-assets/
├── logo/
│   ├── logo-mark.svg               # 64×64 square mark, app icon candidate
│   └── logo-wordmark.svg           # 320×48 horizontal lockup
│
├── icons/                          # 24×24, currentColor
│   ├── icon-mic.svg
│   ├── icon-headset.svg
│   ├── icon-waveform.svg
│   ├── icon-waveform-live.svg      # animated
│   ├── icon-signal.svg
│   ├── icon-live.svg               # animated LIVE pill
│   ├── icon-verified.svg           # Sportradar check
│   ├── icon-esoteric.svg           # disruptor bolt
│   ├── icon-replay.svg
│   ├── icon-flag.svg
│   └── icon-timer.svg
│
├── ui/
│   ├── voice-query-button.svg      # animated, 80×80
│   └── stat-card-template.svg      # 360×140 reference
│
├── hero/                           # WEBSITE HERO ASSETS
│   ├── hero-live-composite.svg     # animated centerpiece — product flow
│   ├── hero-particles.svg          # ambient floating dots + signal pings
│   └── hero-scanlines.svg          # CRT scanline overlay pattern
│
├── product/                        # PRODUCT PREVIEWS
│   ├── spotting-board-preview.svg  # animated desktop spotting board
│   ├── live-dashboard-mockup.svg   # animated producer dashboard (Phase 2)
│   ├── tablet-booth-mockup.svg     # tablet frame with spotting board
│   └── player-card.svg             # generic player card component
│
├── illustrations/
│   ├── pipeline-diagram.svg        # animated architecture flow
│   ├── broadcaster-silhouette.svg  # animated headset/mic illustration
│   └── stadium-silhouette.svg      # 1600×500 cinematic backdrop
│
├── decorative/
│   ├── ticker-bar.svg              # scrolling stats marquee
│   ├── broadcast-tower.svg         # animated tower with signal waves
│   └── signal-radial.svg           # radiating lines, section divider
│
├── backgrounds/
│   ├── hero-stadium-gradient.svg   # 1600×900 atmospheric
│   ├── bg-data-grid.svg            # 400×400 tile-able
│   ├── bg-noise.svg                # 200×200 film grain
│   └── og-banner.svg               # 1200×630 social share
│
└── tools/
    ├── photo-picker.html           # local photo-selection helper
    └── PHOTO-GUIDE.md              # stock photo sourcing guide
```

Animations only run when inlined in the DOM (not via `<img src>`).

---

## The Video Hero — Recommended Composition

Layer these SVGs to build a dynamic, video-like hero section at <20KB total (vs. 2–20MB for an MP4):

```tsx
// app/page.tsx
export default function Hero() {
  return (
    <section className="relative min-h-screen overflow-hidden bg-[#050505]">
      {/* Layer 1: Atmospheric backdrop */}
      <div className="absolute inset-x-0 bottom-0 -z-30 opacity-70 h-1/2">
        <StadiumSilhouette className="w-full h-full" />
      </div>

      {/* Layer 2: Floating particles */}
      <div className="absolute inset-0 -z-20">
        <HeroParticles className="w-full h-full" />
      </div>

      {/* Layer 3: Scanline overlay */}
      <div className="absolute inset-0 -z-10 opacity-30 mix-blend-overlay pointer-events-none">
        <HeroScanlines className="w-full h-full" />
      </div>

      {/* Content */}
      <div className="relative mx-auto max-w-7xl px-8 pt-32 pb-24">
        <div className="max-w-3xl">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-neutral-800 bg-neutral-950 px-3 py-1 font-mono text-xs tracking-widest text-neutral-400">
            <span className="h-2 w-2 animate-pulse rounded-full bg-red-500" />
            LIVE · &lt;200MS · ON-DEVICE
          </div>
          <h1 className="font-mono text-6xl font-bold tracking-tight text-neutral-50">
            The spotter that<br/>never sleeps.
          </h1>
          <p className="mt-6 max-w-xl font-mono text-lg text-neutral-400">
            BroadcastBrain builds your spotting board overnight and surfaces the
            right stat during the 4-second window — before you ask.
          </p>
        </div>

        {/* Hero centerpiece animation */}
        <div className="mt-16">
          <HeroLiveComposite className="w-full h-auto" />
        </div>
      </div>
    </section>
  );
}
```

`hero-live-composite.svg` runs a 6-second loop that tells the entire product story: audio waveform pulses → transcription lines appear → stat card materializes with latency counter. **That one SVG is the demo.**

---

## Using Icons (recolorable)

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

<MicIcon className="h-5 w-5 text-neutral-50" />
<MicIcon className="h-5 w-5 text-red-500" />
```

Or import as a Next.js `Image`:

```tsx
import Image from "next/image";
import micIcon from "@/brand-assets/icons/icon-mic.svg";

<Image src={micIcon} alt="" className="h-5 w-5" />
```

---

## Using Animated SVGs in React

Animations live inside `<style>` blocks within each SVG. They only run when the SVG is **inlined** in the DOM — not when loaded via `<img src>`.

**Option 1: SVGR (recommended for Next.js / Vite)**

```bash
npm i -D @svgr/webpack
# next.config.js
module.exports = {
  webpack(config) {
    config.module.rules.push({ test: /\.svg$/, use: ['@svgr/webpack'] });
    return config;
  },
};
```

```tsx
import HeroLiveComposite from '@/brand-assets/hero/hero-live-composite.svg';
<HeroLiveComposite className="w-full h-auto" />
```

**Option 2: Paste directly as JSX** (best for one-offs)

Copy SVG contents into a component file, convert `class=` → `className=`. The inline `<style>` tag is fine as-is — Tailwind's JIT leaves it alone. Prefer this over runtime HTML string injection for safety.

---

## Website Section Recipes

### "How it works" → pipeline-diagram.svg

```tsx
<section className="border-t border-neutral-900 bg-[#050505] py-32">
  <div className="mx-auto max-w-6xl px-8">
    <div className="mb-12 font-mono text-xs tracking-widest text-neutral-500">
      02 / ARCHITECTURE
    </div>
    <h2 className="font-mono text-4xl font-bold tracking-tight text-neutral-50">
      On-device inference.<br/>Cloud only when it matters.
    </h2>
    <div className="mt-16">
      <PipelineDiagram />
    </div>
  </div>
</section>
```

### "Product" section → spotting-board-preview + tablet-booth-mockup

Pair the two — desktop preview on the left, tablet on the right — to show "your board, any device."

### Section transitions → ticker-bar.svg

Full-bleed band between sections:

```tsx
<div className="border-y border-neutral-900">
  <TickerBar className="w-full" />
</div>
```

### Feature cards → broadcaster-silhouette + broadcast-tower + signal-radial

Three feature cards, each with one animated illustration:
- **broadcaster-silhouette** → "Built for the booth"
- **broadcast-tower** → "Always broadcasting"
- **signal-radial** → "The right stat reaches you"

### Backgrounds

```tsx
<section className="relative min-h-screen">
  <div className="absolute inset-0 -z-10"
       style={{ backgroundImage: `url(/brand-assets/backgrounds/hero-stadium-gradient.svg)`,
                backgroundSize: "cover" }} />
  <div className="absolute inset-0 -z-10 opacity-60 mix-blend-overlay"
       style={{ backgroundImage: `url(/brand-assets/backgrounds/bg-noise.svg)` }} />
  {/* content */}
</section>
```

The grid pattern tiles — drop it as `background-repeat: repeat` for dashboard surfaces.

---

## Stat Card — Live Reference

`stat-card-template.svg` is a visual spec, not a component. Build the React version using its proportions:

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

## OG / Social

Next.js `app/layout.tsx`:

```tsx
export const metadata = {
  title: "BroadcastBrain",
  description: "The spotter that never sleeps. Right stat. Right moment. Under 200ms.",
  openGraph: {
    images: ["/brand-assets/backgrounds/og-banner.svg"],
  },
};
```

Some platforms (Slack, iMessage) prefer PNG for OG. See **Exports** below to flatten.

---

## Swift / iOS (for the Cactus app)

Drop SVGs into `Assets.xcassets` → **Vector Image Set** (Xcode 12+):

1. Drag each `.svg` into `Assets.xcassets`
2. Select the asset → Inspector → **Preserve Vector Data** = ✓, **Scales** = Single Scale
3. Reference:

```swift
Image("icon-mic")
  .renderingMode(.template)
  .foregroundStyle(.white)
```

Animated SVGs won't animate natively in SwiftUI. Options:
- **Rebuild in SwiftUI** — trivial for `icon-live` (`withAnimation`) and `icon-waveform-live` (HStack of Rectangles, staggered delays).
- **Lottie** — convert via LottieFiles, use `LottieView`.

---

## Exports (SVG → PNG)

```bash
brew install librsvg

rsvg-convert -w 2400 hero/hero-live-composite.svg > hero@2x.png
rsvg-convert -w 1200 -h 630 backgrounds/og-banner.svg > og.png
```

Animated frames freeze to frame 0 on export. For a specific frame (e.g., the stat card materialized), temporarily bump `animation-delay` in the SVG before exporting.

---

## Not Included (and why)

- **Team logos, real player headshots, league marks** — licensing risk. Templates use roster initials (`PM`, `JS`) and jersey colors only.
- **Stock photography** — search results were rights-managed. For real stadium/broadcaster photos in the deck, source from Unsplash. See `tools/PHOTO-GUIDE.md`.
- **MP4/WebM video** — deliberately avoided. Animated SVG is ~10–100× smaller, scales to 8K, and doesn't need autoplay workarounds.

---

## Quick Color / Font Check

**If you change brand colors**, update these files (they have hard-coded hex values):
- `logo-mark.svg`, `logo-wordmark.svg` — the red bar
- `icon-live.svg`, `icon-verified.svg`, `icon-esoteric.svg` — status colors
- `stat-card-template.svg`, `voice-query-button.svg` — all tokens
- `hero-stadium-gradient.svg`, `og-banner.svg` — gradient stops

**If you change the typeface** from IBM Plex Mono, update `logo-wordmark.svg`, `icon-live.svg`, `stat-card-template.svg`, and `og-banner.svg`. Everything else is pure geometry.

---

## File Inventory

| Asset | Size | Dimensions | Animated |
|---|---|---|---|
| `hero/hero-live-composite.svg` | ~6KB | 1200×600 | ✓ |
| `hero/hero-particles.svg` | ~2KB | 1600×900 | ✓ |
| `hero/hero-scanlines.svg` | <1KB | tile | — |
| `product/spotting-board-preview.svg` | ~5KB | 900×560 | ✓ |
| `product/live-dashboard-mockup.svg` | ~6KB | 1000×600 | ✓ |
| `product/tablet-booth-mockup.svg` | ~4KB | 520×720 | — |
| `product/player-card.svg` | ~2KB | 340×180 | — |
| `illustrations/pipeline-diagram.svg` | ~4KB | 900×400 | ✓ |
| `illustrations/broadcaster-silhouette.svg` | ~2KB | 240×300 | ✓ |
| `illustrations/stadium-silhouette.svg` | ~3KB | 1600×500 | — |
| `decorative/ticker-bar.svg` | ~3KB | 1200×44 | ✓ |
| `decorative/broadcast-tower.svg` | ~2KB | 200×240 | ✓ |
| `decorative/signal-radial.svg` | ~2KB | 600×400 | ✓ |

**Total pack: ~55KB. Entire website hero < 20KB over the wire.**

---

**Hit the 200ms latency counter on screen during the demo. That number is the moat.**
