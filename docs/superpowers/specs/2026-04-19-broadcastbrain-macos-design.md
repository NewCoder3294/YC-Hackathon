# BroadcastBrain macOS — Design Spec (shipped)

**Date:** 2026-04-19 · **Status:** implemented (commit `331921a` on branch `rebuild`)

This document describes what we actually built. The original detailed spec was lost to a repo reset and is reconstructed from the committed code.

---

## 1. Product

Native SwiftUI macOS app. On-device voice AI for sports commentators. Three surfaces:

| Surface | Purpose | What ships |
|---|---|---|
| **Live** | Press-to-talk. STT → AI → stat card. | Real. Uses Apple `SFSpeechRecognizer` for STT, `CactusService` for completion. |
| **Research Center** | Pre-match prep — notes + grounded Q&A. | Real. `TextEditor` notes (autosaved) + Q&A chat grounded on match cache. |
| **Archives** | Sidebar list of past sessions. | Real. Tap to view transcript, stat cards, notes, research messages. |

Demo match: **Argentina vs France · 2022 WC Final** · bundled in `match_cache.json`.

**Out of scope (intentional cuts):** 3-card stack, always-on listening, Feature 1 spotting board, iPad target, cloud fallback.

---

## 2. Stack

- macOS 14+, SwiftUI, Swift 5.9+ via Xcode 26.4
- `@Observable` stores; no Combine
- `cactus-macos.xcframework` (built from `github.com/cactus-compute/cactus@v1.14`, 4.4 MB)
- `Cactus.swift` bridge from same repo (`apple/Cactus.swift`)
- Apple `Speech` framework (`SFSpeechRecognizer`) for STT — on-device
- `AVAudioEngine` for mic capture
- `JSONEncoder` with `.secondsSince1970` for persistence (lossless round-trip)
- No third-party Swift packages

---

## 3. Architecture

```
BroadcastBrainApp (@main)
  └── ContentView                                    (NavigationSplitView)
       ├── SidebarView                               (Live / Research / Archives + New Session)
       └── Detail pane                               (swaps by selection)
            ├── LivePaneView         ← money shot
            ├── ResearchCenterView   ← HSplitView: notes | Q&A chat
            └── ArchiveDetailView    ← read-only session view

Stores:
  AppStore                     @Observable — selection, liveState, transcript, latency
    ├── SessionStore           JSON-on-disk persistence
    └── CactusService          protocol (RealCactusService | MockResponder)

Services:
  AudioCaptureService          AVAudioEngine + SFSpeechRecognizer
  RealCactusService            wraps cactusInit / cactusComplete / cactusDestroy
  MockResponder                5 scripted stat cards + 6 Q&A answers, 350ms simulated latency
```

---

## 4. Data flow

### Live path
```
[hold mic] → AVAudioEngine → SFSpeechRecognizer (on-device) → partial/final transcript
[release]  → cactusComplete(system + match_cache.facts + transcript) → JSON → StatCard
            → append to Session, save to disk, render
```

### Research path
```
[type + send] → cactusComplete(research system + facts + question) → prose reply
             → ChatMessage(.assistant, grounded=bool) appended
```

---

## 5. Demo safety

- `MOCK_MODE=1` (set by default in scheme) → `MockResponder` substitutes `RealCactusService`
- Substring matches: "mbappe/mbappé", "messi penalty", "penalty", "ascends", "di maria/di maría", "messi"
- Research mode: keyword matches against "mbappé / messi / di maría / peter drury / lusail"
- Unmatched live → `{"no_verified_data":true}` → "No verified data" card
- Real Gemma path: app falls back to `MockResponder` if `~/Library/Application Support/BroadcastBrain/models/gemma.gguf` is missing or fails to load

---

## 6. Design tokens (from `reference/brand-assets/README.md`)

- Surfaces: `#050505 / #0A0A0A / #141414 / #171717`
- Borders: `#262626 / #1A1A1A`
- Text: `#FAFAFA / #A3A3A3 / #737373`
- Accents: live `#EF4444`, verified `#10B981`, esoteric `#F59E0B`
- Type: SF Mono via `Font.system(..., design: .monospaced)`

---

## 7. Bundled primitives (ported from `reference/frontend/design-handoff/feature-2/right-pane.jsx`)

Visual 1:1 translation, not code copy. Names preserved for cross-reference:

| Ported source | Swift target |
|---|---|
| `LivePaneShell` | `LivePaneView` |
| `ListeningDot` | `ListeningDot` |
| `BottomBezel` + `Waveform` | `PressToTalkButton` |
| `CardStack` + `StackCard` | `StackCard` |
| `ScorerStatCard` | `StatCardView` |
| `TranscriptOverlay` | `TranscriptOverlay` |
| `StatusBar` | `StatusBarView` |
| `SportradarBadge` | `SportradarBadge` |
| `LivePill` | `LivePill` |
| `LatencyTag` | `LatencyTag` |

New (no main-branch analogue): `SidebarView`, `ArchiveRow`, `ArchiveDetailView`, `ResearchCenterView`, `ChatMessageRow`, `ContentView`.

---

## 8. Non-negotiables enforced in code

1. Every stat card renders `SportradarBadge` (✓ Sportradar). Verified in `StatCardView`.
2. Airplane glyph in `StatusBarView` permanently on (`isAirplane: true`).
3. No modals. Uses inline error cards + inline states.
4. Commentator drives: press-to-talk only; never auto-listening.
5. `MockResponder` returns `{"no_verified_data":true}` on unmatched prompts — code enforces "—, never guessed."

---

## 9. Build + test

```bash
xcodebuild build -project BroadcastBrain.xcodeproj -scheme BroadcastBrain -destination 'platform=macOS'
xcodebuild test  -project BroadcastBrain.xcodeproj -scheme BroadcastBrain -destination 'platform=macOS'
```

Current: build succeeds, 9 tests (7 pass, 2 skipped waiting on Gemma model weights).

---

## 10. Known gaps

- Gemma 4 weights not downloaded. App ships in `MOCK_MODE` by default. Real on-device Gemma inference is gated on the user downloading weights to `~/Library/Application Support/BroadcastBrain/models/gemma.gguf`.
- No `AppIcon` in asset catalog — bundled icon step deferred to polish.
- UI layout validated via build + test only, not via manual ⌘R rehearsal yet. User validates at Task 10.
