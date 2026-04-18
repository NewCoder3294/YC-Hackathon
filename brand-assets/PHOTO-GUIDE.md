# BroadcastBrain — Photo Sourcing Guide

Real sports/broadcasting photos to complement the SVG asset pack. Every source below is **commercial-use-free, no attribution required** (Unsplash license). Targeted queries + specific photographer recommendations so you spend minutes, not hours.

---

## Where to download (in priority order)

1. **Unsplash** — https://unsplash.com — best quality, clean license, no account needed
2. **Pexels** — https://pexels.com — good coverage of sports + behind-the-scenes
3. **Pixabay** — https://pixabay.com — decent fallback
4. **Wikimedia Commons** — https://commons.wikimedia.org — useful for historic/editorial shots, check individual licenses

⚠️ **Avoid Getty, Shutterstock, AP** — these appeared in earlier search results but are rights-managed. Don't ship those.

---

## Recommended Folder Structure

Add to your existing `assets/` directory:

```
assets/
├── photos/
│   ├── hero/                   # full-bleed backdrops, 2400px+ wide
│   ├── venues/                 # stadiums, arenas, fields
│   ├── production/             # control rooms, cameras, OBS setups
│   ├── broadcasters/           # booth, mic, headset shots
│   ├── gameplay/               # on-field action (generic, no visible logos)
│   ├── crowd/                  # fans, stands, atmosphere
│   └── tech/                   # laptops, screens, data viz irl
```

---

## By Website Section

### HERO SECTION — atmospheric backdrop behind your animated SVG

**Best query:** `https://unsplash.com/s/photos/stadium-lights-night`

What to look for: empty stadium, stadium lights on, dusk/blue-hour, minimal visible branding or team logos. The dark tones will layer well with your `#050505` background using a `mix-blend-multiply` overlay.

**Specific recommended queries:**
- `stadium at night` — wide atmospheric shots, floodlights
- `empty stadium` — architectural, no crowd
- `stadium lights` — close-up of floodlight rigs (great for texture)
- `baseball stadium night` — specifically for MLB demo angle

**Treatment for hero use:**
```tsx
<div className="relative">
  <img
    src="/photos/hero/stadium-night.jpg"
    className="absolute inset-0 w-full h-full object-cover opacity-40"
  />
  <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-[#050505]/80 to-transparent" />
  {/* Your content + SVG composite on top */}
</div>
```

---

### "VENUES" — social proof strip, partnership logos area

**Queries:**
- `sports arena` — NBA-style indoor
- `football field aerial` — top-down NFL
- `baseball diamond` — MLB diamond from above
- `soccer pitch` — global appeal
- `tennis court`
- `hockey rink`

Use these as a multi-sport strip to signal "works for any sport" — which is a direct Phase 3 differentiator in your spec.

**Photographer tip:** Mitch Rosen on Unsplash has outstanding empty stadium shots. Sven Kucinic for arena interiors.

---

### "BUILT FOR THE BOOTH" — broadcaster research validation section

**Queries:**
- `radio microphone studio` — your spec cites Rich Ackerman (WFAN) so this matters
- `broadcast booth` — the physical environment your product lives in
- `podcast studio dark` — similar visual language, more available
- `sports announcer` — mixed results; filter for non-editorial
- `headset microphone professional`

**What to avoid:** photos with recognizable announcers or visible team branding. Stick to generic/silhouette/angle-cropped shots.

**Recommended photographers on Unsplash:**
- **Jonny Gios** — studio + mic shots, consistent dark aesthetic
- **Gabriel Avalos** — broadcast equipment, moody lighting
- **Norbert Braun** — radio/microphone closeups
- **Sam McGhee** — podcasting/broadcasting setups

---

### "PRODUCER DASHBOARD" — Phase 2 section backdrop

**Queries:**
- `broadcast control room` — multi-monitor walls, mission-control feel
- `live production control room` — tons of screens, the "directors chair" vibe
- `tv production studio` — behind-the-scenes
- `streaming setup monitors` — more accessible, cheaper-looking but fine for indie angle

This section is the producer-facing pitch (OBS integration, replay cuing). Lean into the mission-control aesthetic.

**Photographer tips:**
- Alec Favale for control rooms
- Samsung newsroom press photos (on their site, CC-licensed)

---

### "PRE-GAME SPOTTING BOARD" — the wedge product section

**Queries:**
- `clipboard notes sports` — broadcasters still use paper
- `notebook handwritten notes` — the thing you're replacing
- `stats spreadsheet laptop` — the data side
- `tablet on desk dark` — the device your auto-built board shows up on

This is where a before/after visual works: photo of messy handwritten spotting chart next to your clean SVG tablet mockup. That's the product story in one side-by-side.

---

### "GAMEPLAY MOMENTS" — the 4-second window section

**Queries:**
- `football catch action` — motion, energy
- `baseball swing action` — the split-second your product exists for
- `basketball dunk`
- `hockey face-off`
- `soccer header`

⚠️ **Critical:** filter for photos **without** visible NFL/NBA/MLB logos. Generic/youth/amateur/college shots are safer. "Pickup game" as a query modifier helps.

---

### "CROWD ATMOSPHERE" — emotional beat section

**Queries:**
- `stadium crowd night` — silhouetted, atmospheric
- `fans cheering` — works but check for visible team gear
- `sports fans silhouette` — cleanest option
- `stadium lights crowd` — backlit crowd, no faces readable

Use these for big emotional moments. The product exists so the broadcaster captures *this* — the moment the crowd roars.

---

### "TECHNOLOGY" — Cactus + Gemma 4 + on-device story

**Queries:**
- `macbook dark desk` — on-device inference, laptop-centric
- `iphone app dark` — mobile Cactus SDK angle
- `code editor dark terminal` — the build itself
- `server rack data center` — for contrast ("what we avoid")
- `neural network visualization` — abstract AI (use sparingly, cliché)

---

## Quick Download Workflow

1. Open Unsplash in a browser
2. Search each query above, add `?orientation=landscape` if needed
3. Download at largest available resolution (usually 4000-6000px wide)
4. Run through the optimizer below before committing to repo

### Optimization (do this before shipping)

```bash
# Install once
brew install imagemagick webp

# Resize + convert to WebP (smaller + faster)
# Hero images — 2400px wide, high quality
for f in photos/hero/*.jpg; do
  magick "$f" -resize 2400x -quality 82 "${f%.jpg}-lg.webp"
  magick "$f" -resize 1200x -quality 80 "${f%.jpg}-md.webp"
  magick "$f" -resize 600x  -quality 75 "${f%.jpg}-sm.webp"
done

# Section photos — 1600px wide max
for f in photos/{venues,production,broadcasters,gameplay}/*.jpg; do
  magick "$f" -resize 1600x -quality 80 "${f%.jpg}.webp"
done
```

With this, your full photo pack should stay under **3–5MB** total over the wire. Compare to one un-optimized stock photo = 8–15MB.

---

## Next.js Image Usage

```tsx
import Image from 'next/image';

<Image
  src="/photos/hero/stadium-night.webp"
  alt=""
  fill
  priority
  sizes="100vw"
  className="object-cover opacity-40"
/>
```

Pair with a gradient overlay to blend into your dark theme:

```tsx
<div className="relative h-screen">
  <Image src="/photos/hero/stadium-night.webp" alt="" fill priority className="object-cover" />
  <div className="absolute inset-0 bg-[#050505]/70" />
  <div className="absolute inset-0 bg-gradient-to-t from-[#050505] via-transparent to-[#050505]/50" />
  {/* Content */}
</div>
```

---

## Suggested Initial Pull (12 photos, covers the whole site)

To keep scope tight for a hackathon, here's the exact set I'd grab first:

| # | Query | Use | Priority |
|---|---|---|---|
| 1 | `stadium lights night` | Hero backdrop | ★★★ |
| 2 | `empty baseball stadium` | Venues strip | ★★★ |
| 3 | `football field aerial` | Venues strip | ★★ |
| 4 | `basketball arena` | Venues strip | ★★ |
| 5 | `radio microphone studio dark` | Broadcaster section | ★★★ |
| 6 | `broadcast headset professional` | Broadcaster section | ★★ |
| 7 | `broadcast control room` | Producer dashboard section | ★★★ |
| 8 | `tv production studio` | Producer dashboard section | ★★ |
| 9 | `handwritten sports notes` | Spotting board before/after | ★★ |
| 10 | `sports camera sideline` | Production section | ★★ |
| 11 | `stadium crowd silhouette night` | Emotional/atmosphere | ★★ |
| 12 | `macbook dark desk code` | Tech/on-device section | ★★ |

Total download time: ~20 minutes. Total optimization time: ~5 minutes. Total pack size: ~4MB after WebP conversion.

---

## Attribution

Unsplash license doesn't require it, but if you want to include credit anyway (good karma, also flattering if a photographer sees your demo), use a `CREDITS.md`:

```markdown
# Photo Credits

Photos sourced from Unsplash (unsplash.com/license):
- Hero stadium shot — [Photographer Name] — [unsplash URL]
- Control room — [Photographer Name] — [unsplash URL]
...
```

---

## Legal / Licensing Sanity Check

**Safe to ship:**
- Generic stadium exteriors
- Empty fields / arenas
- Equipment closeups (mics, cameras, headsets)
- Silhouetted/backlit crowds
- Behind-the-scenes production shots without visible team branding

**Risky — don't ship:**
- Photos showing NFL/NBA/MLB/NHL team logos clearly
- Recognizable player faces
- Recognizable announcer faces
- League-branded equipment (official game balls, uniforms)
- Screenshots from actual broadcasts

**When in doubt:** crop the logo out, or pick a different photo. Judges won't notice. Lawyers will.

---

**Workflow:** grab the 12 photos from the table above → run the WebP conversion → drop into `assets/photos/` → ship. You'll have a photo-rich landing page in under 30 minutes.
