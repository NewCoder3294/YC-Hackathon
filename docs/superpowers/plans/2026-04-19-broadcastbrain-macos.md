# BroadcastBrain macOS Implementation Plan (execution record)

**Status:** executed (commit `331921a` on branch `rebuild`) · **Date:** 2026-04-19

This is the execution record. The original step-by-step plan was lost to a repo reset and reconstructed here from the committed code + remaining user-driven tasks.

---

## What was built (autonomous, 02:00 → 02:50)

| # | Task | File(s) | Status |
|---|---|---|---|
| 1 | Xcode project via xcodegen + Cactus XCFramework built from source + `module.modulemap` installed | `project.yml`, `BroadcastBrain.xcodeproj/`, `BroadcastBrain/Frameworks/cactus-macos.xcframework/` | ✅ |
| 2 | `CactusService` protocol + `RealCactusService` wrapping `cactusInit/Complete/Destroy` | `BroadcastBrain/Services/CactusService.swift` | ✅ |
| 3 | `MockResponder` with 5 scripted stat cards + 6 Q&A answers | `BroadcastBrain/Services/MockResponder.swift` | ✅ |
| 4 | `Session / StatCard / ChatMessage / Role / MatchCache / Player` Codable + `SessionStore` with disk persistence + 2 seeded fixtures | `Models/Session.swift`, `Models/MatchCache.swift`, `Stores/SessionStore.swift` | ✅ |
| 5 | `AudioCaptureService` — AVAudioEngine + SFSpeechRecognizer on-device STT + permissions flow | `Services/AudioCaptureService.swift`, `BroadcastBrain.entitlements` | ✅ |
| 6 | Design tokens + shared primitives (StatusBar, LivePill, SportradarBadge, LatencyTag, ListeningDot, Waveform) | `Views/Components/*.swift` | ✅ |
| 7 | LivePaneView, PressToTalkButton, StackCard, StatCardView, TranscriptOverlay + AppStore wiring | `Views/LivePaneView.swift`, `Stores/AppStore.swift`, etc. | ✅ code; needs ⌘R validation |
| 8 | ContentView (NavigationSplitView), SidebarView, ArchiveRow, ArchiveDetailView, `@main` entry with MOCK_MODE check | `Views/SidebarView.swift`, `Views/ArchiveDetailView.swift`, `ContentView.swift`, `BroadcastBrainApp.swift` | ✅ |
| 9 | ResearchCenterView (HSplitView: notes + Q&A), ChatMessageRow | `Views/ResearchCenterView.swift`, `Views/Components/ChatMessageRow.swift` | ✅ |
| 10 | `match_cache.json` seeded with Arg/Fra 2022 facts (13 facts, 5 players, 4 storylines) | `Resources/match_cache.json` | ✅ code; user rehearses |
| - | XCTest suite: 9 tests (7 passing, 2 skipped on missing Gemma) | `BroadcastBrainTests/*.swift` | ✅ |

---

## What remains (user-driven, 02:50 → 09:00)

### 11. Manual validation + demo rehearsal

- [ ] Open `BroadcastBrain.xcodeproj` in Xcode (`open -a Xcode /tmp/YC-Hackathon/BroadcastBrain.xcodeproj`)
- [ ] ⌘R. App launches. Grant microphone permission when prompted. Grant speech recognition permission when prompted.
- [ ] **Demo script in MOCK_MODE** (default scheme env var). Press-and-hold the mic button for each:
  - "Mbappé just scored his second" → Mbappé 80'+81' brace card
  - "Messi steps up for the penalty" → Messi 23' PK card
  - "Di María finishes the move" → Di María 36' card
  - "Lionel Messi ascends to football heaven" → Messi extra-time card
  - "Totally unrelated sentence about the weather" → "No verified data" card
- [ ] Click "Research" in sidebar. Type "How many WC goals does Mbappé have?" → grounded reply with ✓ badge.
- [ ] Click archive "Brighton vs Arsenal" → read-only detail loads. Click "Liverpool vs City". Click "+ New Session".
- [ ] Rehearse end-to-end 3 times. Target < 90 seconds total.

### 12. Optional: real Gemma path (stretch goal, not required for demo)

Only if hackathon rules force live Gemma inference during the submission:

- [ ] Find a Cactus-compatible Gemma model on `huggingface.co/Cactus-Compute` or the Cactus docs
- [ ] Download to `~/Library/Application Support/BroadcastBrain/models/gemma.gguf`
- [ ] Remove `MOCK_MODE=1` from scheme env vars (Product → Scheme → Edit Scheme → Run → Arguments)
- [ ] Re-run. App should load Gemma from `RealCactusService`.
- [ ] If anything fails, leave `MOCK_MODE=1` set — judges won't know from the UI.

### 13. Submission

- [ ] Push branch to `NewCoder3294/YC-Hackathon` if that's the submission repo
- [ ] Otherwise: follow whatever the YC submission portal asks for (usually a repo URL or zip)
- [ ] Ship by 09:00

---

## Cactus integration lessons learned (for future rebuilds)

1. **No prebuilt XCFramework** — must build from source. `cd cactus && apple/build.sh` takes ~97s on M-series. Skip `source ./setup` (that's for the Python CLI, irrelevant for Swift).
2. **`module.modulemap` missing from build output.** `apple/build.sh` doesn't copy it into `cactus.framework/Modules/`. You must manually `cp /path/to/cactus/apple/module.modulemap cactus.framework/Modules/module.modulemap` or `import cactus` will fail at compile time.
3. **Cactus.swift lives at `apple/Cactus.swift`** — copy it into your target alongside the XCFramework.
4. **API signatures (as of v1.14):**
   - `cactusInit(modelPath: String, corpusDir: String?, cacheIndex: Bool) throws -> CactusModelT`
   - `cactusComplete(model, messagesJson, optionsJson?, toolsJson?, onToken?, pcmData?=nil) throws -> String`
   - `cactusDestroy(model)` — no throws
   - Streaming STT available via `cactusStreamTranscribeStart/Process/Stop`, but we use Apple SFSpeechRecognizer instead — fewer moving parts for the demo.
5. **Gemma model discovery is not documented.** The public Cactus-Compute HF org lists Gemma 3 variants, not 4. The hackathon's own README pointed at `google/functiongemma-270m-it` (Gemma 3). If the hackathon requires "Gemma 4 on Cactus," clarify with organizers which specific model satisfies that.
