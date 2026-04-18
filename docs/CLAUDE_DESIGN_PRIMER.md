# BroadcastBrain — Design Brief (inline pack · iPad · Arg vs Fra 2022)

Claude Design can't accept folders/zips in my setup, so the full context pack is inline below.
I'll also attach 6 SVG files individually: logo-mark.svg, logo-wordmark.svg, icon-live.svg,
icon-verified.svg, icon-waveform-live.svg, icon-timer.svg.

---

## PRODUCT

On-device voice AI for sports broadcasters. Listens to the match, surfaces the right stat
at the right moment on a visual dashboard, answers questions on voice command, never
interrupts the broadcaster's flow. Validated with 4 working broadcasters (see research section).

## PLATFORM — iPad (landscape-primary)

Designing for iPad (Pro or Air, 10.2"+), landscape orientation. The spotting board and live
dashboard live side-by-side in a split layout — no tab switching during a match. iPadOS-native
feel. Demo runs on physical iPad mirrored to stage screen via AirPlay.

**Why iPad and not iPhone:** Pat McCarthy specifically described broadcasters as viewing on
"tablet in booth". Bob Heussler's handwritten charts are paper-sized — iPad replaces paper,
not a phone. Booth lighting is dim; peripheral-vision glanceability requires larger type than
a phone screen can provide.

## DEMO MATCH (chosen deliberately, do not change)

**Argentina vs France — 2022 FIFA World Cup Final · 18 December 2022 · Lusail Stadium, Qatar**

Most-watched match in history (~1.5B viewers), dense in stat-worthy moments (Messi pen 23',
Di María 36', Mbappé 80'+81', Messi ET, Mbappé ET, penalty shoot-out). Zero "what sport is
this?" overhead with international judges. Every broadcast clip (Peter Drury's Messi call)
is iconic and on YouTube.

**Hero players for stat cards:** Lionel Messi (Argentina #10), Kylian Mbappé (France #10).
Both scored hat-tricks in the final.

## WHAT WE'RE DESIGNING (exactly 3 features, nothing else)

1. Pre-match Auto Spotting Board
2. Live Stat Whisper (live match dashboard) — the money shot
3. Opt-in Voice Query

## NON-NEGOTIABLE DESIGN RULES (from broadcaster interviews)

1. Every stat shows its source (Sportradar ✓). Missing data = "—", never guessed.
2. Visual-first, silent by default. No popups, no modal interruptions.
3. Peripheral-vision-friendly: primary stat is the biggest thing on any card. On iPad this means
   genuinely large — think 48–64pt mono for hero numbers, not phone-scale 20pt.
4. iPadOS airplane-mode indicator visible in status bar on every frame.
5. "The broadcaster stays in control." AI surfaces, broadcaster decides. Never auto-anything.

## iPad LAYOUT PRIMITIVE (shared across all 3 features)

```
┌─ iPad landscape · ~10.2" · status bar shows airplane mode ─────────────┐
│                                                                         │
│  ┌─ SPOTTING BOARD PANE (left ~60%) ─┬─ LIVE PANE (right ~40%) ─────┐  │
│  │                                    │                               │  │
│  │  Argentina squad  │ France squad   │  Live stat card (when active)│  │
│  │  player cards     │ player cards   │  OR idle listening state     │  │
│  │  scrollable       │ scrollable     │                               │  │
│  │                                    │  Side widgets (bottom):      │  │
│  │                                    │   • xG ticker                │  │
│  │                                    │   • Story reminder queue     │  │
│  │                                    │                               │  │
│  │                                    │  Voice query button           │  │
│  │                                    │   (bottom bezel, press-hold) │  │
│  └────────────────────────────────────┴──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

Every design frame should render this split layout. Feature 1 frames focus on the left pane,
Feature 2/3 frames focus on the right pane — but show both in context.

---

## VISUAL LANGUAGE (LOCKED — from the asset pack README)

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


---

## REFERENCE COMPONENT: stat-card-template.svg (used in Feature 2)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 140" fill="none">
  <rect width="360" height="140" rx="8" fill="#0A0A0A"/>
  <rect x="0.5" y="0.5" width="359" height="139" rx="7.5" stroke="#262626"/>
  <!-- Top row: live indicator + timestamp -->
  <circle cx="20" cy="20" r="4" fill="#EF4444"/>
  <text x="30" y="24" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="10" font-weight="700" fill="#A3A3A3" letter-spacing="0.15em">LIVE • Q3 8:42</text>
  <text x="340" y="24" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="10" fill="#737373" letter-spacing="0.1em" text-anchor="end">142ms</text>
  <!-- Stat -->
  <text x="20" y="62" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="13" fill="#737373" letter-spacing="0.08em">PATRICK MAHOMES</text>
  <text x="20" y="92" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="22" font-weight="700" fill="#FAFAFA" letter-spacing="-0.01em">12 TDs, 0 INTs in December</text>
  <!-- Source badge -->
  <g transform="translate(20 108)">
    <circle cx="6" cy="6" r="5.5" fill="#10B981" fill-opacity="0.1" stroke="#10B981" stroke-width="0.75"/>
    <path d="M3.5 6.25l1.75 1.75 3.25-3.5" stroke="#10B981" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <text x="18" y="10" font-family="'IBM Plex Mono', ui-monospace, monospace" font-size="10" fill="#10B981" letter-spacing="0.05em">Sportradar</text>
  </g>
</svg>

```

---

## REFERENCE COMPONENT: voice-query-button.svg (used in Feature 3)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" fill="none">
  <style>
    .ring { animation: ring 2s ease-out infinite; transform-origin: 40px 40px; }
    @keyframes ring {
      0%   { transform: scale(0.9); opacity: 0.6; }
      100% { transform: scale(1.3); opacity: 0; }
    }
  </style>
  <circle class="ring" cx="40" cy="40" r="34" stroke="#EF4444" stroke-width="1" fill="none"/>
  <circle cx="40" cy="40" r="30" fill="#0A0A0A" stroke="#262626"/>
  <circle cx="40" cy="40" r="26" fill="#141414"/>
  <g transform="translate(40 40)" stroke="#FAFAFA" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <rect x="-4" y="-10" width="8" height="14" rx="4"/>
    <path d="M-8 -1v1a8 8 0 0 0 16 0v-1"/>
    <path d="M0 8v4"/>
    <path d="M-4 12h8"/>
  </g>
</svg>

```

---


## Broadcaster interview quotes (from Broadcaster Market Research Analysis)

### Pat McCarthy — NY Mets radio play-by-play
- "While he uses AI tools like ChatGPT for pre-game research, he is wary of using 'voice agents'
  during live games, fearing it would cause sensory overload."
- "He believes play-by-play is naturally 'off the cuff,' where stories are woven into the
  broadcast organically rather than through a scripted or AI-prompted process."
- Pat's insight: the tool may be even more immediately effective for the statistician at the
  table than for the on-air talent directly.

### Bob Heussler — Brooklyn Nets radio play-by-play, Fairfield on ESPN
- "He spends hours creating detailed handwritten charts, numerical charts, and storyline
  outlines for every player to ensure he can recognize them visually by body type or hair."
- "He keeps his own handwritten 'running score' to track momentum and scoring runs in real-time."
- "Despite describing himself as an 'old' broadcaster, he actively uses ChatGPT for prep work,
  though he remains a 'devil's advocate' regarding the necessity of absolute accuracy in
  AI-generated stats."

### Rich Ackerman — 30yrs WFAN / CBS Sports Radio (Ivy League FB, CBB, Mets, Giants, Nets fill-in)
- "He strongly believes in conducting his own research and creating his own 'spotting boards'
  rather than hiring outside researchers, as he feels this makes the information resonate
  better and flow more naturally during a broadcast."

### Trey Redfield — Syracuse-trained PxP, now local news Iowa
- "He believes that while broadcasters spend hours or even days preparing for a single game,
  they often only use about 25% of their notes; therefore, he sees great value in technology
  that helps announcers think faster and access 'dynamic' storylines in real-time."


**Research honesty for soccer:** the 4 broadcasters are MLB / NBA / hockey / multi-sport radio.
None is a dedicated football/soccer commentator. The generic pain pattern (25% of prep used,
handwritten spotting boards, accuracy paranoia) validated across all four. Soccer is the demo
sport because of the 2022 World Cup Final's universal recognisability.

---

## FULL PRODUCT SPEC (3 features in detail)

# BroadcastBrain — Hackathon Spec v2 (Focused 3-Feature Build, Soccer Edition)

**Hackathon:** YC Voice Agents Hackathon 2026 · Cactus + Gemma 4 · April 18–19, 2026
**Team:** 4 generalists (no iOS) · **Budget:** ~22 hours
**Target tracks:** Best On-Device Enterprise Agent (B2B) + Deepest Technical Integration

This supersedes `SPEC.md` for the hackathon build. The v1 SPEC is the full vision; this is the focused 3-feature MVP we ship on the clock.

---

## Why this demo match

**Argentina vs France — 2022 FIFA World Cup Final · 18 December 2022 · Lusail Stadium, Qatar**

Picked deliberately for the demo:
- **Most-watched football match in history** (~1.5B viewers). Every judge has an opinion on it. Zero "what sport is this?" overhead.
- **Dense in stat-worthy moments** the product can surface: Messi's 23rd-minute penalty, Di María's 36th-minute finish, Mbappé's 80th + 81st-minute brace (the fastest two-minute two-goal brace in a final ever), Messi's extra-time goal, Mbappé's extra-time equaliser, the penalty shoot-out.
- **Pre-caching is trivial** — this match is over. Every stat exists, every broadcast call is on YouTube. Perfect for airplane-mode demo.
- **Peter Drury's Messi call** ("Lionel Messi ascends to football heaven...") is the single most recognisable football broadcast clip ever made. Using that as our live-pipeline input is both emotional and a clear "on-device transcription works" proof.

**Hero players for the demo:** Lionel Messi (Argentina #10), Kylian Mbappé (France #10). Both scored hat-tricks (Mbappé's was the first in a WC final since 1966). Every stat card either hero triggers will land with the room.

---

## Why iPad (not iPhone)

The broadcaster research explicitly pointed at **iPad in the booth**:

> Pat McCarthy (NY Mets): "broadcasters can view on tablet in booth" — his primary surface, not a phone.
> Bob Heussler (Brooklyn Nets): hand-draws boards on paper-sized sheets — an iPad replaces paper, not a phone.

**Design implications for iPad (landscape, 10.2"+ form factor):**
- Primary surface is a split layout: spotting board left, live dashboard right. No tab switching during a match.
- Larger stat cards — 2–3× the type size of a phone layout. Booth lighting is dim; peripheral-vision glanceability matters more than screen real-estate economy.
- Voice query button lives along the bottom bezel of the screen — natural thumb reach when the iPad is resting on a desk/booth shelf.
- Running score tracker, story reminder queue, and streak alerts can live *in-frame* alongside the primary stat card (on iPhone they'd need to hide/collapse).

**Demo device:** physical iPad (Pro preferred, Air fine). Mirrored to stage screen via AirPlay or USB-C. Airplane mode on from second 0.

---

## What we're building

A voice-powered AI employee for sports broadcasters. Listens to the match, knows every player, surfaces the right stat the instant it's relevant, and answers any question on demand — all on-device, airplane-mode-safe. Validated with 4 working broadcasters (Brooklyn Nets, NY Mets, CBS Sports Radio, local markets).

**Research honesty:** those 4 broadcasters are MLB / NBA / hockey / multi-sport radio. None was a dedicated soccer commentator. The generic pain pattern (25% of prep used, handwritten spotting boards, accuracy paranoia, visual-first non-intrusive surface) validated across all four. **Pitch response when asked:** *"We validated the problem pattern across MLB, NBA, and hockey broadcasting. We chose the 2022 World Cup Final as the demo because it's the most-watched match in history — every judge can read it instantly. The soccer expansion is the next interview batch, not the pitch."*

---

## The 3 Features

### Feature 1 — Pre-match Auto Spotting Board *(the wedge, validated by all 4 interviews)*

Broadcasters spend hours — sometimes days — hand-building a "spotting board" before every match. They use ~25% of it. BroadcastBrain builds the full board automatically overnight, from the football stats APIs, formatted exactly how a broadcaster would lay it out.

**Research anchors:**
- Bob Heussler: "spends hours creating detailed handwritten charts, numerical charts, and storyline outlines for every player"
- Rich Ackerman: "strongly believes in conducting his own research and creating his own spotting boards"
- Pat McCarthy: mix of own research + network-provided research teams; uses ChatGPT for prep
- Trey Redfield: broadcasters "only use about 25% of their notes" — the stat that powers the whole pitch

**UX (iPad, landscape):**
- Open app → home shows the match card (**Argentina vs France · 18 Dec 2022 · Lusail Stadium · FIFA World Cup Final**). Tap.
- Split layout loads instantly: Argentina left (light blue/white header), France right (navy header), 23-player squads each side.
- Each player card: portrait headshot, **#10 · FW · Lionel Messi (ARG)**, three stat lines for the tournament (goals, assists, xG), one storyline ("*Seeking his first World Cup trophy at age 35, last dance*"), one matchup note ("*Has scored in every knockout round this tournament*"). Every stat shows a `Sportradar ✓` source badge.
- Tap a player card → full player profile takes over: tournament-wide stats, career stats, last-5-matches form, head-to-head vs specific France defenders.
- **Edit board:** long-press a stat → replace from alternatives; tap-to-pin keeps a specific stat pinned. Preferences persist per team.
- **Export PDF:** paper backup for the booth in case the device dies.
- **Works in airplane mode from load onward** — all data is cached locally at match start.

**Data flow:**
```
Overnight (T-12hrs):
  Stats API (Sportradar Soccer / FIFA data)
    ↓ squads, tournament stats, match history, news, injuries
  Gemma 4 (on-device, one call per player)
    ↓ generates { top_stats, storyline, matchup_note }
  Bundled into app → opens offline
```

**Gemma 4 prompt (per player, inherit shape from SPEC.md §1.0):**
```
You are building a broadcaster's spotting board entry for {player_name} ({position}) ahead
of the 2022 FIFA World Cup Final.

Tournament stats: {tournament_stats_json}
Career stats: {career_stats_json}
Matchup: {opposing_nation}, likely opposing defenders/attackers: {matchup_players}

Generate JSON only:
{
  "top_stats": [ "stat line 1", "stat line 2", "stat line 3" ],
  "storyline": "one sentence — narrative arc, milestone, or current form",
  "matchup_note": "one sentence — performance vs today's opponent or head-to-head"
}

Rules: concise, broadcaster-ready. Every stat must come from the payload, not invention.
If a field is missing, output "—".
```

**Accuracy rule:** if the stats payload is missing a field, the card shows `—`, not a guess. Every stat in the UI shows its source. One fabricated stat ends a broadcaster's career — this is non-negotiable.

**Scope this hackathon:** one match (Argentina vs France 2022 Final). 46 players total (23 + 23). All data bundled in app.

---

### Feature 2 — Live Stat Whisper *(the money shot, validated by Pat + Trey)*

During the match, the iPad listens continuously. When something stat-worthy happens, a card appears on screen — non-intrusive, never audio. Broadcaster glances, decides whether to use it, carries on.

**Research anchors:**
- Pat McCarthy: wary of voice agents during live games, *"fearing sensory overload"* → the whisper is visual-only by design
- Pat: play-by-play is "off the cuff" → the AI must never interrupt
- Trey Redfield: tech should help broadcasters "think faster and access 'dynamic' storylines in real-time"

**Soccer-specific event triggers** (continuous flow, not discrete plays like baseball):
- **Goal** — highest-priority card: scorer season stats + tournament stats + historical comparison
- **Shot on target / big chance** — shooter's tournament shot conversion, xG
- **Key pass / assist** — creator's chance-creation stats for the tournament
- **Foul / yellow / red** — card context, player discipline record
- **Substitution** — incoming player's tournament impact stats
- **Corner / set-piece** — team set-piece conversion rate this tournament
- **VAR review** — pause the whisper during review, resume when result is confirmed
- **Half-time / full-time / extra-time / shoot-out transitions** — narrative recap cards

**UX (iPad, split panel — always visible alongside spotting board):**
- iPad sits on the desk, landscape, in peripheral vision. Broadcaster is talking continuously.
- Messi scores the 23rd-minute penalty. Broadcaster calls the goal.
- ~800ms later: **soft orange dot pulses top-right of the Live panel.** No sound.
- Stat card animates into the Live panel:
  ```
  ⚽ MESSI
  23' PEN · 1-0 ARGENTINA
  6th goal of tournament · 2nd WC Final goal of career
  1st player to score in every WC knockout round (group, R16, QF, SF, Final)
  Sportradar ✓                  [842ms]
  ```
- Broadcaster finishes sentence, glances, reads it naturally into his next beat.
- Card stays visible 8 seconds then fades. If not used, it's gone — no dismissal required.
- Next event triggers a new card. One card at a time; newer supersedes an unused older one.
- **Dup suppression:** Gemma 4's own STT hears the broadcaster's speech; if the stat was already spoken on air, don't re-surface.
- **Latency counter** visible in demo mode (tiny, bottom-right corner). Hidden in prod.

**Data flow (fully on-device via Gemma 4 multimodal):**
```
iPad mic (expo-av, 2s rolling window)
    ↓ audio chunk
Gemma 4 multimodal (Cactus, on-device) — ONE CALL:
    • transcribes audio (native multimodal)
    • extracts structured context (player, event, situation)
    • decides stat_opportunity
    • function-calls get_player_stat(player, situation) against local cache
    • generates final stat_text with source
    ↓
Event bus → Live panel renders card
```

**Why one Gemma 4 call instead of Whisper → LLM:** Gemma 4 on Cactus is multimodal (voice in, function calling, structured output, native). This eliminates an entire layer (no separate Whisper), lowers latency, and is exactly the technical integration Cactus/DeepMind judges want to see demoed.

**Gemma 4 function signatures (soccer-shaped):**
```ts
get_player_stat(player_name: string, situation: string)
  → { stat_text, stat_value, source: "Sportradar", confidence: "high"|"medium" }

get_team_stat(team: string, metric: string)        // possession, xG, set-piece %, etc.
get_match_context(match_id: string)                // live score, minute, booking count
get_historical(player: string, comparison: string) // career records, WC-specific splits
```
All resolved against pre-cached `match_cache.json` — zero network calls during the live demo.

**Routing:** simple stat lookups → Gemma 4 on-device end-to-end. Complex historical comparisons (e.g., *"most goals in a WC final since 1966"*) → Cactus hybrid routes to Gemini. Routing decision is emitted by Gemma 4 itself via a `query_complexity: "simple"|"complex"` field. Demo must work airplane-mode, so demo path is simple.

**Latency budget (realistic on-device, RN + Cactus on iPad):**

| Stage | Target |
|-------|--------|
| Audio buffer fill | ~500ms |
| Gemma 4 multimodal (STT + extract + function call + generate) | ~400ms |
| Dashboard render | ~50ms |
| **Total** | **~950ms** |

SPEC v1 quoted 200ms — that was native iOS with a separate Whisper model. Realistic for this stack is **~1 second**. Still comfortably inside the soccer "eventful moment → next touch" window. Show the real number in the demo; be honest.

**Proactive features (add if hours 12–18 allow):**
- **Live xG ticker** *(adapt from Bob Heussler's "running score tracker" ask)*: xG-for / xG-against drifting as the match progresses. A goal's xG value animates onto the ticker when scored.
- **Streak / milestone alerts** *(Trey Redfield)*: Messi's *"score in every knockout round"* streak pre-computed; if he's gone through a round without scoring, flag visually as at risk.
- **Story reminder queue** *(Rich Ackerman)*: side panel of broadcaster's pre-planned storylines ("Messi's 5th WC — last dance", "Mbappé chasing Golden Boot"); STT detects which have been mentioned, surfaces unmentioned during lulls. Directly ties the *"25% of prep"* stat into the product.

These are bonus. Don't add until Feature 2 base works end-to-end.

---

### Feature 3 — Opt-in Voice Query *(the voice agent; statistician/analyst persona)*

Broadcaster presses a button, speaks a question in plain English, gets a sourced answer on screen + spoken aloud in under 2 seconds. The "ask anything" escape hatch for moments when the proactive whisper doesn't cover it.

**Research honesty:**
- None of the four interviewees are soccer broadcasters, and none is a colour commentator. This feature's target persona (voice-first + natural dead air) was *inferred*.
- Pat McCarthy explicitly *did not want* voice prompting mid-call.
- Pat's own insight: *"the tool may be even more immediately effective for the statistician at the table than for the on-air talent directly."*
- **Pitch framing:** lead with Pat's statistician-angle quote. Frame voice query as the tool the *statistician / analyst* uses to serve the on-air talent at 10× speed. Don't oversell as "every broadcaster wants this" — that's not what the research shows.

**Why we're still building it:** this is a Voice Agents hackathon. Gemma 4's multimodal voice input is a core capability judges want to see demoed. Feature 2 is voice *sense* (audio → context → stat); Feature 3 is voice *ask* (user queries directly). Without Feature 3 we're demoing a listening app, not a voice agent.

**UX (iPad):**
- Big press-to-talk button anchored along the bottom bezel of the iPad, both-thumbs-reach. No wake word (wake words cause accidental triggers mid-call — validated concern).
- User presses and holds → soft *"ding"* → screen shows **"Listening…"** with a waveform animation filling the centre of the live panel.
- Speaks: *"How many goals has Mbappé scored in World Cups?"*
- Releases button (or 8-second auto-cutoff).
- **"Thinking…"** shimmer (~1.5s) while Gemma 4 transcribes + function-calls the local data.
- Answer card appears on the live panel **and** plays through bluetooth earpiece if opt-in TTS is enabled:
  ```
  🎤 "How many goals has Mbappé scored in World Cups?"

  Mbappé career WC goals: 12
  Youngest player to reach 10 WC goals since Pelé
  Qatar 2022: 8 goals · leading Golden Boot
  Sportradar ✓                        [1.4s]
  ```
- If Gemma 4 can't ground the answer (e.g., *"what's his favourite food?"*), the app responds: **"I don't have verified data on that."** This is a *trust feature*, not a failure mode. Validated by Bob Heussler's "devil's advocate on accuracy" concern — a broadcaster would rather hear "I don't know" than a confident wrong answer.

**Data flow (same on-device Gemma 4 multimodal pipeline as Feature 2):**
```
Button press → audio capture (expo-av, up to 8s)
    ↓
Gemma 4 multimodal (Cactus): transcribe + function-call → { stat_text, source, confidence }
    ↓
Live panel renders answer card + (if opt-in) expo-speech reads it aloud
```

**Function calls exposed to Gemma 4** — same toolbox as Feature 2, all resolved against the pre-cached `match_cache.json`. No live network calls during the demo.

**Accuracy rule:** every answer cites `Sportradar ✓`. If confidence is `medium`, card shows `~` prefix and is **not** spoken via TTS (spoken answers = high-confidence only).

---

## Shared Architecture

```
┌─ iPad (React Native + Expo) ────────────────────────────────────────┐
│                                                                      │
│  UI (React Native, landscape-primary, split-pane)                   │
│    ├─ SpottingBoardPane (left ~60%) ← Feature 1                     │
│    └─ LiveDashboardPane (right ~40%) ← Features 2 + 3               │
│                                                                      │
│  State (Zustand event bus)                                          │
│    ├─ stat_card, transcript, context  (emitted by pipeline)         │
│    └─ voice_query, opt_in_tts         (emitted by UI)               │
│                                                                      │
│  Pipeline                                                            │
│    ├─ AudioCapture (expo-av, rolling 2s + press-to-talk)            │
│    └─ askGemma(input, context, routing) ──────┐                     │
│                                                ↓                     │
│  Cactus RN SDK ──► Gemma 4 on-device (multimodal)                   │
│                       • STT                                          │
│                       • context extraction                           │
│                       • function calling                             │
│                       • text generation                              │
│                       • optional routing → Gemini (cloud)            │
│                                                                      │
│  Data                                                                │
│    └─ assets/match_cache.json (pre-fetched Arg vs Fra 2022 bundle)  │
│                                                                      │
│  TTS: expo-speech (Feature 3 opt-in only)                           │
└──────────────────────────────────────────────────────────────────────┘
```

**Single integration contract** (all three features call this):
```ts
askGemma(input: { prompt?: string, audio?: ArrayBuffer }, context: object, routing: 'auto'|'local'|'cloud')
  → Promise<{
      stat_text: string,
      source: string,
      confidence: 'high' | 'medium',
      player?: string,
      latency_ms: number,
      transcript?: string,    // Feature 3: what the user said
    }>
```

**Stack fallback** (if Cactus RN binding doesn't expose Gemma 4 multimodal in the JS layer in time): wrap the Cactus native iPadOS SDK in an Expo config plugin + thin native module. One person owns this. Resolved in the Sprint 0 pre-work spike.

---

## Shared UX Rules (apply to all three features)

1. **Source citation is non-negotiable.** Every stat shows `Sportradar ✓`. If data is unavailable, `—` not a guess.
2. **Confidence markers.** `high` renders normally. `medium` gets a `~` prefix and is **never spoken** via TTS.
3. **Airplane mode from demo second 0.** All three features work offline because the match data is bundled. Only cloud routing (Gemini for complex historical queries) needs network, and we route around that for the demo.
4. **Latency counter visible only in demo mode.** Bottom-right corner, tiny. Real measured ms. Real numbers beat marketed numbers with YC partners.
5. **One-handed, peripheral-vision-friendly type.** Booth lighting is dim. The iPad competes with a paper team-sheet and a scoreboard.
6. **Never interrupt the call.** Visual-first, silent. Voice output only when explicitly opted in via button. Pat McCarthy's validated constraint.
7. **The broadcaster stays in control.** The AI surfaces, the broadcaster decides. Never auto-posts, auto-speaks, auto-anything.

---

## What we're NOT building

Explicitly deferred from SPEC v1, don't touch unless hours 18–20 are uneventful:

- Phase 2 OBS graphics overlay trigger
- Phase 2 viral clip flagging
- Phase 2 replay director cueing
- Director dashboard
- Multi-sport (MLB, NBA, NFL) — soccer only, one match
- Multi-match (other World Cup matches, Premier League games) — Argentina vs France 2022 only
- Wake word activation — button-press only
- Matchup-to-matchup memory (Phase 3 roadmap)
- Any feature not directly demoable in the 5-minute stage demo

---

## Demo Script (5 minutes, tight)

**Setup:** iPad on stage stand, mirrored to big screen. **Airplane mode on, visible in status bar from second 0.**

| Time | Beat |
|------|------|
| 0:00–0:30 | Problem + research. "Broadcasters spend hours on prep, use 25%. We talked to 4 of them — NY Mets, Brooklyn Nets, CBS Sports Radio, local markets. Every one of them hand-builds a spotting board." Show one Pat McCarthy quote on screen. |
| 0:30–1:30 | **Feature 1.** Open the pre-built spotting board for Argentina vs France 2022. Scroll Messi's card — tournament stats, storyline ("Seeking his first World Cup at 35"), matchup note. Tap-expand to full profile. "This took zero minutes. Built overnight. Gemma 4 on Cactus, on-device." |
| 1:30–3:00 | **Feature 2 — money shot.** Play the Peter Drury audio from Messi's 23rd-minute penalty (*"Argentina are ahead…"*). ~1 second later, stat card lands: *"6th of tournament · 1st player to score in every WC knockout round."* Latency counter visible. "Gemma 4 multimodal — audio in, function-calls local data, stat out. No internet. This is airplane mode." Then play Mbappé's 80th-minute strike — another card, another real number on the counter. |
| 3:00–4:00 | **Feature 3.** Press the voice button. *"How many goals has Mbappé scored in World Cups?"* Answer on screen + spoken in ~1.5s. Follow up with *"What about his favourite food?"* → *"I don't have verified data on that."* "Statistician's new best friend. We say 'I don't know' instead of guessing — that's how we earn broadcaster trust." |
| 4:00–5:00 | Pitch close. "Broadcasters today. Live field reporters next. Every professional who needs the right context in the moment after that. The on-device story isn't a feature — it's the latency and trust requirement. Kill-the-WiFi is our moat." |

**Three things judges will remember:**
1. Airplane-mode indicator on the iPad status bar the entire demo.
2. Latency counter showing a real sub-1-second number.
3. The Messi audio + the stat card landing beat the audio's reverb decay.

---

## File Structure

```
broadcastbrain/
├── app.json                         # Expo config, Cactus native plugin, iPad primary
├── assets/
│   └── match_cache.json             # Pre-fetched Arg vs Fra 2022 Final bundle
├── src/
│   ├── cactus/
│   │   ├── askGemma.ts              # The single integration contract
│   │   ├── prompts.ts               # Inherited from SPEC.md §1.0, §1.3, §1.5
│   │   ├── functions.ts             # get_player_stat, get_team_stat, ...
│   │   └── native/                  # Native module glue (Expo config plugin)
│   ├── data/
│   │   ├── sportradar.ts            # Overnight fetcher (Node script, runs once)
│   │   └── spottingBoard.ts         # Feature 1 pipeline
│   ├── audio/
│   │   └── capture.ts               # expo-av rolling + press-to-talk
│   ├── pipeline.ts                  # Orchestrator: audio → askGemma → event bus
│   ├── screens/
│   │   └── MatchScreen.tsx          # Single split-pane iPad landscape screen
│   ├── panes/
│   │   ├── SpottingBoardPane.tsx    # Feature 1 UI (left ~60%)
│   │   └── LiveDashboardPane.tsx    # Features 2 + 3 UI (right ~40%)
│   ├── components/
│   │   ├── PlayerCard.tsx
│   │   ├── LiveStatCard.tsx
│   │   ├── FlashingCue.tsx
│   │   ├── VoiceQueryButton.tsx
│   │   ├── AnswerCard.tsx
│   │   └── LatencyCounter.tsx       # demo mode only
│   └── state/events.ts              # Zustand event bus
├── SPEC.md                          # v1 — full vision
└── SPEC_v2.md                       # this file — hackathon build
```

---

## Success Criteria

- Feature 1: opens on iPad in airplane mode, shows both 23-player squads with stats + storylines + source badges, split landscape layout.
- Feature 2: 30s Peter Drury clip of Messi's 23rd-minute penalty → stat card on right panel with measured latency < 1.5s, `Sportradar ✓` cited.
- Feature 3: button press → voice question → sourced answer on right panel + spoken aloud in < 2s. Knows when to say "I don't have verified data on that."
- Entire demo runs on the iPad in airplane mode, no cables to a laptop, no fallback.
- Backup demo video recorded by hour 20 as insurance.

---

## Open Questions for Pre-Kickoff (Sprint 0)

1. Cactus RN SDK — does it expose Gemma 4 multimodal audio input directly on iPad running Expo? **Spike this first.** If not, need the Expo config plugin + native module route.
2. Which Sportradar / football data endpoints hold archived 2022 World Cup match data? Alternate source: StatsBomb Open Data (free, detailed event data for this match specifically).
3. Hardware button for Feature 3 voice query — on-screen bottom-bezel button only, or optional external puck (Flic)? Recommend on-screen only for demo simplicity.
4. Who is the dedicated "prompt tuner" in Track A — the prompts in SPEC.md §1.0, §1.3, §1.5 are v1 and will need 2–3 hours of iteration against the real Peter Drury audio fixtures.
5. Which 3–4 audio clips (goals / key moments) do we bundle as live-pipeline fixtures? Candidates: Messi's 23rd-min pen, Di María's 36th-min finish, Mbappé's 80th+81st brace, Messi's extra-time goal, the penalty shoot-out sequence.


---

## HOW WE'LL WORK

I will send 3 feature prompts, in this order: Feature 2 (Live Dashboard) → Feature 1
(Spotting Board) → Feature 3 (Voice Query).

For each feature you produce:
- Hi-fi iPad landscape frames for every listed state
- One "hero" frame per feature (for the submission deck)
- Animation/haptic notes
- One broadcaster quote from the research section that justifies each design choice

VISUAL LANGUAGE IS LOCKED — only the hex tokens above, only IBM Plex Mono, only the icons
attached or referenced in the assets README. If you feel the urge to invent a new colour or
icon, stop and ask first.

Acknowledge you've read this entire brief and then wait for my Feature 2 prompt.
