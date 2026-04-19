# BroadcastBrain

> On-device voice AI for sports commentators. Built in native SwiftUI for macOS. Gemma 4 + Cactus on-device, Apple Speech framework for always-on transcription. All offline.

**Submitted to:** YC Voice Agents Hackathon 2026 · Cactus + Gemma 4 · April 18–19
**Branch:** `rebuild` (native Swift, orphan history)
**Demo match:** Argentina vs France, 2022 World Cup Final (pre-cached, airplane-mode)

---

## What it does

Three surfaces in one macOS window. All offline.

1. **Live** — tap the mic to go live. BroadcastBrain listens continuously via on-device speech recognition. Every time the commentator finishes a phrase, Gemma 4 evaluates whether the match facts surface a relevant stat card. Stats are bounded by a curated match cache — if no verified fact matches, the card says so.
2. **Research Center** — pre-match prep surface. Freeform notes (autosaved) plus a Q&A chat grounded on the match cache. Same Gemma path, different prompt shape.
3. **Archives** — every session is saved to disk. Tap any past session to see the transcript, stat cards surfaced, notes, and research conversation.

Everything runs on-device. No network calls during demos.

---

## Build

Requires Xcode 15+ (we used 26.4), macOS 14+, `cmake`, `xcodegen` (both via Homebrew).

```bash
# Clone
git clone https://github.com/NewCoder3294/YC-Hackathon.git
cd YC-Hackathon
git checkout rebuild

# Generate project
xcodegen generate

# Build + run
xcodebuild build -project BroadcastBrain.xcodeproj -scheme BroadcastBrain -destination 'platform=macOS'
open -a Xcode BroadcastBrain.xcodeproj    # ⌘R to launch in Xcode
```

First launch asks for microphone + speech recognition permissions. Grant both.

## Test

```bash
xcodebuild test -project BroadcastBrain.xcodeproj -scheme BroadcastBrain -destination 'platform=macOS'
```

9 tests. 7 run unconditionally; 2 skip unless the Gemma model is present at `~/Library/Application Support/BroadcastBrain/models/gemma.gguf`.

---

## Modes

- **`MOCK_MODE=1`** (set in the default scheme): the live path substitutes a `MockResponder` that returns scripted stat cards keyed on transcript substrings. This is the designated demo path — predictable, fast, airplane-safe, no model download needed.
- **Unset**: app looks for Gemma weights at the above path. If found, `RealCactusService` loads them via the bundled Cactus XCFramework. If not, falls through to `MockResponder` with a console warning.

Demo transcript triggers (MOCK_MODE):

- "Mbappé just scored his second" → Mbappé 80'+81' brace card
- "Messi steps up for the penalty" → Messi 23' PK card
- "Di María finishes the move" → Di María 36' card
- "Lionel Messi ascends to football heaven" → Messi ET 108' card
- Anything else → "No verified data on that" card

---

## Architecture

```
BroadcastBrain/
├── BroadcastBrainApp.swift           @main entry, wires MOCK_MODE toggle
├── ContentView.swift                 NavigationSplitView host
├── Models/                           Session, StatCard, ChatMessage, MatchCache (Codable)
├── Stores/
│   ├── AppStore.swift                @Observable top-level state
│   └── SessionStore.swift            JSON-on-disk persistence + 2 seeded fixtures
├── Services/
│   ├── CactusService.swift           protocol + RealCactusService (wraps Cactus.swift)
│   ├── MockResponder.swift           5 scripted stat cards + 6 Q&A answers
│   ├── AudioCaptureService.swift     AVAudioEngine + SFSpeechRecognizer, segment-restart loop
│   └── Cactus.swift                  from github.com/cactus-compute/cactus @ v1.14
├── Views/                            LivePaneView, ResearchCenterView, SidebarView, ArchiveDetailView
└── Frameworks/
    └── cactus-macos.xcframework/     built locally via apple/build.sh

reference/                            main-branch design handoff (read-only)
docs/superpowers/
├── specs/2026-04-19-broadcastbrain-macos-design.md
└── plans/2026-04-19-broadcastbrain-macos.md
```

## Design

Every visual ported from the main branch handoff at `reference/frontend/design-handoff/`:

- **Tokens**: `#050505` base, IBM Plex Mono family (falls back to SF Mono), `#EF4444` live, `#10B981` verified, `#F59E0B` esoteric
- **Typography**: hero stat 48pt, player name 20pt, body 13pt, chip 11pt — all monospaced
- **Primitives ported 1:1**: `LivePaneShell`, `ListeningDot`, `Waveform`, `StackCard`, `ScorerStatCard`, `TranscriptOverlay`, `StatusBar`, `SportradarBadge`, `LivePill`, `LatencyTag`

---

## Cactus build notes

Cactus does not publish prebuilt XCFrameworks. To rebuild:

```bash
git clone https://github.com/cactus-compute/cactus
cd cactus/apple && ./build.sh
# Output: ~/cactus/apple/cactus-macos.xcframework
# MUST manually install the modulemap the build script omits:
cp /path/to/cactus/apple/module.modulemap \
   /path/to/cactus-macos.xcframework/macos-arm64/cactus.framework/Modules/module.modulemap
```

Build takes ~97 seconds on M-series. Do **not** run `source ./setup` — that installs the Python CLI (torch, transformers) which is not needed for Swift.

---

## What's explicitly out of scope

- iPad target (designed for follow-up, same SwiftUI source should compile)
- Precedent + counter-narrative card stack (cut from main-branch spec to demo one clean surface)
- Always-on listening without a toggle (mic is on when you tap it)
- Cloud fallback (on-device only by design)
- Real Gemma weights bundled (too large for git; download at runtime)

## Non-negotiables

1. Every stat card shows `Sportradar ✓`. Null Gemma response → "No verified data" card. Never guessed.
2. Airplane-mode glyph visible in titlebar. No network during demo.
3. Visual-first. No modals. No popups.
4. Commentator stays in control. AI surfaces, commentator decides.
