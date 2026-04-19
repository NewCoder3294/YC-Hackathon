import SwiftUI
import AVFoundation
import Speech
import AppKit

struct LivePaneView: View {
    @Environment(AppStore.self) private var store
    @State private var audio = AudioCaptureService()
    @State private var permState: PermissionState = .unknown
    @State private var debounceTask: Task<Void, Never>?
    /// Dedups sentences shipped to `handleSegment`. Replaces the prefix-match
    /// `lastHandledSegment` that was mis-emitting on STT revisions.
    @State private var sentenceExtractor = SentenceExtractor()
    @State private var showEndConfirm: Bool = false
    @State private var whisperArmed: Bool = false
    @State private var recordingStartedAt: Date?

    enum PermissionState: Equatable {
        case unknown
        case ok
        case micDenied
        case speechDenied
        case bothDenied

        var bannerText: String? {
            switch self {
            case .unknown, .ok: return nil
            case .micDenied: return "Microphone access is off. Enable in System Settings → Privacy & Security → Microphone."
            case .speechDenied: return "Speech Recognition is off. Enable in System Settings → Privacy & Security → Speech Recognition."
            case .bothDenied: return "Microphone and Speech Recognition are off. Enable both in System Settings."
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                StatusBarView(
                    matchTitle: store.currentSession.title,
                    isAirplane: true,
                    latencyMs: store.lastLatencyMs
                )

                HSplitView {
                    // Left: running transcript
                    transcriptColumn

                    // Right: stat cards surfaced
                    statCardsColumn
                }

                Divider().background(Color.bbBorder)

                broadcastConsole
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgBase)
            .blur(radius: showEndConfirm ? 3 : 0)
            .animation(.easeInOut(duration: 0.15), value: showEndConfirm)

            if showEndConfirm {
                endConfirmOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .task { refreshPermissionState() }
        .onDisappear {
            if store.liveState == .listening {
                audio.stop()
                store.liveState = .idle
            }
        }
    }

    /// Custom end-match confirmation that matches the app's dark / mono language
    /// — replaces the default macOS .confirmationDialog.
    private var endConfirmOverlay: some View {
        ZStack {
            // Dimmed backdrop (tap to cancel)
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showEndConfirm = false }
                }

            // Dialog card
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.live)
                    Text("END THIS RECORDING?")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.textPrimary)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.bgSubtle)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.bbBorder).frame(height: 1)
                }

                // Body
                VStack(alignment: .leading, spacing: 10) {
                    row(label: "TRANSCRIPT", value: "\(transcriptLineCount) lines")
                    row(label: "STAT CARDS", value: "\(store.currentSession.statCards.filter { $0.kind == .stat }.count)", valueColor: .verified)
                    row(label: "WHISPERS",   value: "\(store.currentSession.statCards.filter { $0.kind == .whisper }.count)", valueColor: .esoteric)
                    Divider().background(Color.bbBorder).padding(.vertical, 4)
                    Text("Saved to Archive · accessible any time.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                }
                .padding(20)

                // Buttons
                VStack(spacing: 8) {
                    Button(action: { showEndConfirm = false; endMatch() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 12))
                            Text("END & SAVE TO ARCHIVE")
                                .font(Typography.chip)
                                .tracking(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.live)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { showEndConfirm = false }
                    }) {
                        Text("CANCEL")
                            .font(Typography.chip)
                            .tracking(0.6)
                            .foregroundStyle(Color.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.bgSubtle)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 420)
            .background(Color.bgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.bbBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
        }
    }

    private func row(label: String, value: String, valueColor: Color = .textPrimary) -> some View {
        HStack {
            Text(label)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
            Spacer()
            Text(value)
                .font(Typography.statLabel)
                .foregroundStyle(valueColor)
        }
    }

    private var transcriptLineCount: Int {
        let t = store.currentSession.transcript
        guard !t.isEmpty else { return 0 }
        return t.split(separator: "\n").count
    }

    private var transcriptColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LIVE TRANSCRIPT")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                if store.liveState == .listening {
                    HStack(spacing: 6) {
                        ListeningDot()
                        Text("LISTENING")
                            .font(Typography.chip)
                            .foregroundStyle(Color.live)
                    }
                } else if case .error = store.liveState {
                    Text("ERROR")
                        .font(Typography.chip)
                        .foregroundStyle(Color.live)
                }

                Button(action: clearSession) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSubtle)
                }
                .buttonStyle(.plain)
                .help("Clear transcript and stat cards in this session")
                .disabled(store.currentSession.transcript.isEmpty && store.currentSession.statCards.isEmpty)
            }

            if let banner = permState.bannerText {
                permissionBanner(banner)
            }

            if let warning = store.inferenceWarning {
                inferenceBanner(warning)
            }

            if case .error(let msg) = store.liveState {
                StackCard(kind: .counter) {
                    Text(msg)
                        .font(Typography.body)
                        .foregroundStyle(Color.live)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if store.currentSession.transcript.isEmpty && store.partialTranscript.isEmpty {
                            transcriptEmptyState
                        }

                        if !store.currentSession.transcript.isEmpty {
                            let lines = store.currentSession.transcript.split(separator: "\n")
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                transcriptLine(
                                    text: String(line),
                                    isLatest: idx == lines.count - 1 && store.partialTranscript.isEmpty
                                )
                            }
                        }

                        if !store.partialTranscript.isEmpty && store.liveState == .listening {
                            partialLine(store.partialTranscript)
                                .id("__partial__")
                        }

                        Color.clear.frame(height: 1).id("__bottom__")
                    }
                    .padding(18)
                }
                .onChange(of: store.partialTranscript) { _, _ in
                    withAnimation { proxy.scrollTo("__bottom__", anchor: .bottom) }
                }
                .onChange(of: store.currentSession.transcript) { _, _ in
                    withAnimation { proxy.scrollTo("__bottom__", anchor: .bottom) }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
        }
        .padding(20)
        .frame(minWidth: 360)
        .background(Color.bgBase)
    }

    /// Empty state for the LIVE TRANSCRIPT column — big graphic + example pills.
    private var transcriptEmptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.live.opacity(0.4), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.live)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("READY FOR KICK-OFF")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.textPrimary)
                    Text(permState.bannerText != nil
                         ? "Grant permissions above first."
                         : "Tap the mic to go live. Every phrase you say appears here.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().background(Color.bbBorder.opacity(0.5))

            VStack(alignment: .leading, spacing: 8) {
                Text("TRY SAYING")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                FlowLayout(spacing: 6) {
                    examplePill("Mbappé just scored his second")
                    examplePill("Messi takes the penalty")
                    examplePill("Di María finishes the move")
                }
                Text("OR WHISPER")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                    .padding(.top, 4)
                FlowLayout(spacing: 6) {
                    examplePill("How many WC goals does Mbappé have?", amber: true)
                    examplePill("Tell me about Di María", amber: true)
                }
            }
        }
    }

    private func examplePill(_ text: String, amber: Bool = false) -> some View {
        Text("\"\(text)\"")
            .font(Typography.chip)
            .foregroundStyle(amber ? Color.esoteric : Color.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background((amber ? Color.esoteric : Color.textMuted).opacity(0.08),
                        in: Capsule())
            .overlay(Capsule().stroke((amber ? Color.esoteric : Color.textMuted).opacity(0.3), lineWidth: 1))
    }

    private func transcriptLine(text: String, isLatest: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Rectangle()
                .fill(isLatest ? Color.live.opacity(0.6) : Color.bbBorder)
                .frame(width: 2)
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundStyle(isLatest ? Color.textPrimary : Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func partialLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Rectangle()
                .fill(Color.live)
                .frame(width: 2)
                .opacity(0.9)
            (Text(text) + Text(" ▋").foregroundColor(Color.live))
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statCardsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STAT CARDS")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                if !store.currentSession.statCards.isEmpty {
                    Text("\(store.currentSession.statCards.count)")
                        .font(Typography.chip)
                        .foregroundStyle(Color.verified)
                }
            }

            ScrollView {
                VStack(spacing: 12) {
                    if store.currentSession.statCards.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cards surface here as you speak.")
                                .font(Typography.body)
                                .foregroundStyle(Color.textMuted)
                            Text("Try: \"Mbappé just scored his second\" · \"Messi takes the penalty\" · \"Di María finishes\"")
                                .font(Typography.chip)
                                .foregroundStyle(Color.textSubtle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(store.currentSession.statCards.reversed()) { card in
                        StatCardView(card: card)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
        }
        .padding(20)
        .frame(minWidth: 360)
        .background(Color.bgBase)
    }

    private func permissionBanner(_ text: String) -> some View {
        StackCard(kind: .counter) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.slash")
                    .foregroundStyle(Color.live)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Permission required")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.textPrimary)
                    Text(text)
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Open Mic Settings") {
                            openSettings(section: "Privacy_Microphone")
                        }
                        Button("Open Speech Settings") {
                            openSettings(section: "Privacy_SpeechRecognition")
                        }
                        Button("Re-check") {
                            refreshPermissionState()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Bottom-anchored broadcast console. Unifies mic, whisper, and live
    /// ambient counters into one visually coherent dock.
    private var broadcastConsole: some View {
        let isListening = store.liveState == .listening
        let statCount = store.currentSession.statCards.filter { $0.kind == .stat }.count
        let whisperCount = store.currentSession.statCards.filter { $0.kind == .whisper }.count
        let wordCount = store.currentSession.transcript
            .split(whereSeparator: { $0.isWhitespace })
            .count

        return HStack(alignment: .center, spacing: 28) {
            // Left: on-air status centered above the BTW · WHISPER button
            VStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(isListening ? "ON AIR · \(clockString(at: ctx.date))" : "OFF AIR")
                        .font(Typography.chip)
                        .foregroundStyle(isListening ? Color.live : Color.textSubtle)
                        .tracking(1.2)
                        .monospacedDigit()
                }
                whisperButton
            }
            .frame(minWidth: 160)

            Spacer()

            // Centered primary mic + waveform
            PressToTalkButton(
                isListening: isListening,
                onToggle: matchButtonTapped
            )

            Spacer()

            // Right: compact SESSION stat box
            sessionStatsBox(stats: statCount, whispers: whisperCount, words: wordCount)
                .frame(minWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.bgRaised.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    /// Compact session-stats card. Smaller type, tighter padding, boxed.
    private func sessionStatsBox(stats: Int, whispers: Int, words: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SESSION")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .tracking(1.4)

            Divider().background(Color.bbBorder.opacity(0.5))

            compactMetric(
                systemImage: "checkmark.seal.fill",
                tint: .verified,
                label: "STATS",
                value: "\(stats)"
            )
            compactMetric(
                systemImage: "bubble.left.and.text.bubble.right.fill",
                tint: .esoteric,
                label: "WHISPERS",
                value: "\(whispers)"
            )
            compactMetric(
                systemImage: "text.alignleft",
                tint: .textMuted,
                label: "WORDS",
                value: "\(words)"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
    }

    private func compactMetric(systemImage: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(tint)
                .frame(width: 11)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .tracking(0.3)
            Spacer(minLength: 14)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func clockString(at now: Date) -> String {
        guard let started = recordingStartedAt else { return "00:00" }
        let secs = max(0, Int(now.timeIntervalSince(started)))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Count overlapping leading words between two already-lowercased strings.
    /// Used to de-duplicate cumulative SFSpeechRecognizer segments where the new
    /// segment repeats the previous one with drift (punctuation / casing added).
    private static func overlapWords(prev: String, curr: String) -> Int {
        let p = prev.split(whereSeparator: { $0.isWhitespace })
        let c = curr.split(whereSeparator: { $0.isWhitespace })
        var count = 0
        for i in 0..<min(p.count, c.count) {
            let a = p[i].trimmingCharacters(in: .punctuationCharacters)
            let b = c[i].trimmingCharacters(in: .punctuationCharacters)
            if a == b {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// Small floating whisper trigger — the `/btw` equivalent. Only active while
    /// recording. One tap arms the next segment to be routed as a whisper.
    private var whisperButton: some View {
        let isListening = store.liveState == .listening
        let canArm = isListening

        return VStack(spacing: 8) {
            Button(action: { if canArm { whisperArmed.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(whisperArmed ? Color.esoteric : Color.bgRaised)
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(whisperArmed ? Color.esoteric : Color.bbBorder, lineWidth: whisperArmed ? 3 : 1)
                        .frame(width: 56, height: 56)
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(whisperArmed ? Color.bgBase : (canArm ? Color.esoteric : Color.textSubtle))
                }
            }
            .buttonStyle(.plain)
            .disabled(!canArm)

            Text(whisperArmed ? "WHISPER ARMED" : "BTW · WHISPER")
                .font(Typography.chip)
                .foregroundStyle(whisperArmed ? Color.esoteric : Color.textSubtle)
                .tracking(0.5)

            agentWhisperChip
        }
    }

    /// Small pill that shows whether the always-on 30s whisper engine is
    /// running. Tapping it toggles the engine while the mic is still open —
    /// it does NOT stop the mic.
    private var agentWhisperChip: some View {
        let isListening = store.liveState == .listening
        let running = store.whisperEngine.isRunning

        return Button(action: toggleAgentWhisper) {
            HStack(spacing: 5) {
                Image(systemName: running ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(running ? Color.verified : Color.textSubtle)
                Text(running ? "AGENT · 30s" : "AGENT · OFF")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(running ? Color.verified : Color.textSubtle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (running ? Color.verified.opacity(0.12) : Color.bgSubtle),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(running ? Color.verified.opacity(0.5) : Color.bbBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isListening)
        .opacity(isListening ? 1 : 0.5)
        .help("Auto-whisper: every 30 seconds the agent surfaces a stat useful for the next play.")
    }

    private func toggleAgentWhisper() {
        guard store.liveState == .listening else { return }
        if store.whisperEngine.isRunning {
            store.whisperEngine.stop()
        } else {
            store.whisperEngine.start()
        }
    }

    /// Match mic tap routing:
    ///   - If not listening → start the match (no dialog — kick-off should be fast)
    ///   - If listening → open confirm dialog (end-of-match ritual)
    private func matchButtonTapped() {
        if store.liveState == .listening {
            showEndConfirm = true
        } else {
            startListening()
        }
    }

    private func endMatch() {
        // 1. Stop mic cleanly
        audio.stop()
        debounceTask?.cancel()
        sentenceExtractor.reset()
        whisperArmed = false
        recordingStartedAt = nil
        store.liveState = .idle
        store.partialTranscript = ""
        store.whisperEngine.stop()
        store.speech.stop()

        // 2. Save any final transcript progress
        store.sessionStore.save(store.currentSession)

        // 3. Capture id, prepare fresh session so next match is clean
        let finishedId = store.currentSession.id
        let hadContent = !store.currentSession.transcript.isEmpty
            || !store.currentSession.statCards.isEmpty

        if hadContent {
            // Reuse the same match for the next recording — don't re-prompt
            // the commentator for team/sport info after each match.
            store.newSessionKeepingCurrentMatch()
        }

        // 4. Route to Archive detail view for the just-ended session
        store.selectedSurface = .archive
        store.selectedArchiveId = finishedId
    }


    private func clearSession() {
        store.currentSession.transcript = ""
        store.currentSession.statCards = []
        store.partialTranscript = ""
        store.sessionStore.save(store.currentSession)
    }

    private func openSettings(section: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(section)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func inferenceBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.esoteric)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI UNAVAILABLE")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.esoteric)
                    .tracking(0.5)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.esoteric.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.esoteric.opacity(0.5), lineWidth: 1)
        )
    }

    private func refreshPermissionState() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        print("[perm] mic=\(micStatus.rawValue) speech=\(speechStatus.rawValue)")

        let micBad = micStatus == .denied || micStatus == .restricted
        let speechBad = speechStatus == .denied || speechStatus == .restricted

        switch (micBad, speechBad) {
        case (true, true): permState = .bothDenied
        case (true, false): permState = .micDenied
        case (false, true): permState = .speechDenied
        case (false, false):
            if micStatus == .authorized && speechStatus == .authorized {
                permState = .ok
            } else {
                permState = .unknown
            }
        }
    }

    private func toggleListening() {
        if store.liveState == .listening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        // Immediate visible feedback — flip to processing so user sees the tap registered
        store.liveState = .processing
        store.partialTranscript = "Starting…"

        Task { @MainActor in
            do {
                print("[live] requesting permissions…")
                try await audio.requestPermissions()
                print("[live] permissions OK")
                refreshPermissionState()

                audio.onPartial = { partial in
                    Task { @MainActor in
                        guard store.liveState == .listening else { return }
                        // The speakers feed audio back into the mic — STT
                        // happily transcribes our own TTS. Drop everything
                        // captured while speaking (plus a short cooldown) and
                        // advance the cumulative marker so the echoed text
                        // never re-enters the pipeline once TTS ends.
                        if store.speech.isEchoLikely {
                            lastHandledSegment = partial.trimmingCharacters(in: .whitespacesAndNewlines)
                            return
                        }
                        store.partialTranscript = partial

                        // Extract any COMPLETE sentences that ended since last
                        // check, and ship each as its own transcript line + Gemma
                        // call. Incomplete tail stays in partial (italic).
                        await emitCompleteSentences(fromCumulative: partial, forceFinal: false)
                    }
                }
                audio.onSegment = { segment in
                    Task { @MainActor in
                        if store.speech.isEchoLikely {
                            // Echoed TTS reached isFinal — discard it entirely.
                            lastHandledSegment = ""
                            return
                        }
                        // SFSpeechRecognizer fired isFinal — treat whatever remains
                        // as a final sentence even if it doesn't end in punctuation.
                        // Dedup in SentenceExtractor carries across task boundaries
                        // so a final segment that repeats an already-shipped partial
                        // is correctly suppressed. No per-task reset here.
                        await emitCompleteSentences(fromCumulative: segment, forceFinal: true)
                    }
                }
                audio.onError = { err in
                    Task { @MainActor in
                        print("[live] audio error: \(err.localizedDescription)")
                        store.liveState = .error(err.localizedDescription)
                    }
                }

                print("[live] starting audio engine…")
                try audio.start()
                store.liveState = .listening
                store.partialTranscript = ""
                if recordingStartedAt == nil { recordingStartedAt = Date() }
                store.whisperEngine.start()
                print("[live] LISTENING")
            } catch let e as AudioError {
                print("[live] AudioError: \(e.localizedDescription)")
                refreshPermissionState()
                store.liveState = .error(e.localizedDescription)
            } catch {
                print("[live] other error: \(error.localizedDescription)")
                refreshPermissionState()
                store.liveState = .error(error.localizedDescription)
            }
        }
    }

    private func stopListening() {
        audio.stop()
        debounceTask?.cancel()
        sentenceExtractor.reset()
        store.liveState = .idle
        store.partialTranscript = ""
        recordingStartedAt = nil
        store.whisperEngine.stop()
        store.speech.stop()
    }

    /// Extract any complete sentences from the current cumulative transcript
    /// and ship each as its own transcript line + Gemma call. Dedup lives in
    /// `SentenceExtractor` — STT revisions (comma added/dropped, word
    /// substituted) do not cause re-emission.
    @MainActor
    private func emitCompleteSentences(fromCumulative cumulative: String, forceFinal: Bool) async {
        let sentences = sentenceExtractor.ingest(cumulative: cumulative, forceFinal: forceFinal)
        for sentence in sentences {
            await handleSegment(sentence)
        }
    }

    @MainActor
    private func handleSegment(_ segment: String) async {
        let transcript = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        // Consume whisper-armed flag: next segment is forced as a whisper answer.
        let forceWhisper = whisperArmed
        if forceWhisper { whisperArmed = false }

        print("[live] segment: \(transcript) · forceWhisper=\(forceWhisper)")

        store.appendTranscript(transcript)
        store.partialTranscript = ""

        let started = Date()

        // Grounding sources, strongest first:
        //   (a) live ESPN play-by-play — cached to
        //       ~/Library/Application Support/BroadcastBrain/playbyplay/<league>/<gameId>.json
        //       via PlayByPlayKit's LiveSession. PlayByPlayStore.plays mirrors
        //       that JSON; we feed the whole thing to Gemma so score + minute
        //       questions can be answered off the disk cache even for games
        //       that have already finished polling.
        let livePlays = store.playByPlayStore.plays
        let compact = store.playByPlayStore.currentCompact
        let playsBlock = WhisperEngine.renderPlays(livePlays, compact: compact)
        let havePlays = !playsBlock.isEmpty

        let cache = store.matchCacheForCurrentSession
        let facts = cache?.facts.prefix(8).joined(separator: "\n- ") ?? ""
        let haveFacts = !facts.isEmpty
        let haveGrounding = havePlays || haveFacts

        // Short-circuit whisper-armed queries when we have nothing to ground on.
        // Gemma-1B will happily invent "Currently, the score is 0-0." from thin
        // air — distinguish between "feed hasn't polled yet" and "no stream
        // attached" so the commentator knows which one.
        if forceWhisper && !haveGrounding {
            let isLoading = store.playByPlayStore.isStreaming
            let msg = isLoading
                ? "The live feed is still loading — give it a few seconds and try again."
                : "No live feed is attached to this session, so I can't answer that."
            let card = StatCard(
                kind: .whisper,
                player: "Agent",
                rawTranscript: transcript,
                latencyMs: 0,
                answer: msg
            )
            store.appendStatCard(card)
            store.speech.speak(msg)
            print("[live] whisper skipped — no grounding (streaming=\(isLoading))")
            return
        }

        let system = """
        You are a sports broadcast agent for a live football commentator. Route the
        commentator's last utterance to one of two output kinds — this is the
        Cactus-routing contract.

        1) If the utterance is a BROADCAST MOMENT (describing something that just
           happened on the pitch — a goal, foul, booking, substitution, etc.),
           return a STAT CARD:
           {"type":"stat","player":"…","stat_value":"…","context_line":"…","source":"Sportradar","confidence":"high"|"medium"}

        2) If the utterance is a QUERY (the commentator is asking a side question —
           contains "?", starts with "how"/"what"/"when"/"why"/"tell me"/"compare",
           or is otherwise interrogative), return a WHISPER ANSWER:
           {"type":"whisper","player":"…optional subject player…","answer":"a 1-2 sentence grounded answer","source":"Sportradar"}

        If the utterance is prefixed with [BTW], the commentator explicitly
        triggered whisper mode — FORCE a whisper answer regardless of phrasing.

        Ground every answer in the data block below. The "Recent plays" list is
        the official ESPN feed — it is the authoritative source for live state
        like the current score, minute, possession, goals, cards, and subs.
        Match facts give pre-match context.

        If BOTH the plays list and the facts list are missing or say "(no data)",
        return {"no_verified_data":true}. Do NOT invent scores, minutes, or
        stats. Return ONLY a single JSON object — no prose, no markdown fences.
        """
        // Prefix [BTW] so Gemma's system prompt routes this as a whisper
        // regardless of phrasing.
        let utterance = forceWhisper ? "[BTW] \(transcript)" : transcript
        let factsBlock = haveFacts ? "- \(facts)" : "(no data)"
        let playsRendered = havePlays ? playsBlock : "(no data — no live feed attached)"
        let user = """
        Match: \(store.currentSession.title).

        Recent plays (most recent last, \(livePlays.count) total from ESPN feed):
        \(playsRendered)

        Match facts:
        \(factsBlock)

        Commentator just said: "\(utterance)".
        """

        do {
            let reply = try await store.cactus.complete(system: system, user: user)
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            store.lastLatencyMs = latency
            store.inferenceWarning = nil

            if let card = parseStatCard(reply, raw: transcript, latencyMs: latency) {
                // A whisper-type card must be grounded in plays or facts. Gemma
                // emits confident answers even when the data block is empty, so
                // guard this here — appending an ungrounded whisper to the UI
                // is worse than surfacing nothing.
                if card.kind == .whisper && !haveGrounding {
                    print("[live] whisper rejected — ungrounded answer=\((card.answer ?? "").prefix(80))")
                    return
                }
                store.appendStatCard(card)
                // Whisper answers are user-directed prose — speak them. Stat
                // cards are visual only.
                if card.kind == .whisper, let answer = card.answer, !answer.isEmpty {
                    store.speech.speak(answer)
                }
            } else if forceWhisper {
                // Gemma-1B frequently emits prose instead of JSON even when
                // the system prompt forbids it. The prose is only trustworthy
                // if we actually handed Gemma grounding data (plays or facts).
                // Without grounding, any specific number it produces is a
                // hallucination — refuse to speak it.
                if !haveGrounding {
                    let msg = "No live feed is attached to this session, so I can't answer that."
                    let card = StatCard(
                        kind: .whisper,
                        player: "Agent",
                        rawTranscript: transcript,
                        latencyMs: latency,
                        answer: msg
                    )
                    store.appendStatCard(card)
                    store.speech.speak(msg)
                    print("[live] whisper refused — no grounding; raw=\(reply.prefix(120))")
                } else if let fallback = Self.proseFallbackAnswer(from: reply) {
                    let card = StatCard(
                        kind: .whisper,
                        player: "Agent",
                        rawTranscript: transcript,
                        latencyMs: latency,
                        answer: fallback
                    )
                    store.appendStatCard(card)
                    store.speech.speak(fallback)
                    print("[live] prose fallback whisper: \(fallback)")
                } else {
                    print("[live] whisper reply unusable, raw=\(reply.prefix(200))")
                }
            }
        } catch {
            print("Gemma error on segment '\(transcript)': \(error)")
            store.inferenceWarning = "Inference failed: \(error.localizedDescription)"
        }
    }

    /// Best-effort conversion of a prose Gemma reply into a single-sentence
    /// whisper answer. Strips markdown fences, drops any leading meta-chatter
    /// ("Okay, let's break down…"), and caps at ~220 chars so TTS doesn't
    /// narrate a page of text.
    private static func proseFallbackAnswer(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Split on blank lines; prefer the first paragraph that isn't a
        // Gemma-ism like "Please provide me with the context!".
        let paragraphs = trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let meaningless: [String] = [
            "please provide",
            "i need more information",
            "as an ai",
            "i am a large language model",
            "i'm sorry",
            "okay, let's"
        ]
        let candidate = paragraphs.first(where: { p in
            let lower = p.lowercased()
            return !meaningless.contains(where: { lower.hasPrefix($0) })
        }) ?? paragraphs.first
        guard var answer = candidate else { return nil }
        // Strip common markdown artefacts.
        answer = answer
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // If the paragraph is itself a JSON-ish blob, drop it — the structured
        // parser already had its shot.
        if answer.hasPrefix("{") { return nil }
        // Keep a single sentence for TTS sanity.
        if let terminator = answer.firstIndex(where: { ".!?".contains($0) }) {
            let end = answer.index(after: terminator)
            answer = String(answer[..<end])
        }
        if answer.count > 220 {
            answer = String(answer.prefix(220)) + "…"
        }
        return answer.isEmpty ? nil : answer
    }

    private func parseStatCard(_ json: String, raw: String, latencyMs: Int) -> StatCard? {
        // Gemma 1B often wraps JSON in prose or ```json fences. Scan for the
        // first balanced {...} block instead of trusting the whole reply to
        // parse.
        guard let jsonBlock = Self.extractFirstJSON(json),
              let data = jsonBlock.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if obj["no_verified_data"] as? Bool == true { return nil }

        let src = obj["source"] as? String ?? "Sportradar"
        let typeStr = obj["type"] as? String ?? "stat"

        // Whisper card — commentator query routed to a prose answer
        if typeStr == "whisper" {
            let answer = (obj["answer"] as? String) ?? ""
            let player = (obj["player"] as? String) ?? "Whisper"
            guard !answer.isEmpty else { return nil }
            return StatCard(
                kind: .whisper,
                player: player,
                rawTranscript: raw,
                latencyMs: latencyMs,
                answer: answer
            )
        }

        // Stat card — autonomous broadcast moment
        guard
            let player = obj["player"] as? String,
            let stat = obj["stat_value"] as? String,
            let ctx = obj["context_line"] as? String
        else { return nil }
        // When we have a match-specific cache applied, refuse cards about
        // players who aren't on that match's roster. This catches Gemma
        // falling back to the seeded Argentina/France facts for unrelated
        // games.
        if let cache = store.matchCacheForCurrentSession,
           !Self.playerIsInCache(player, cache: cache) {
            print("[live] rejecting stat card — player '\(player)' not in cache for \(cache.title)")
            return nil
        }
        return StatCard(
            kind: .stat,
            player: player,
            statValue: stat,
            contextLine: ctx,
            source: src,
            rawTranscript: raw,
            latencyMs: latencyMs
        )
    }

    private static func playerIsInCache(_ player: String, cache: MatchCache) -> Bool {
        let p = player.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return false }
        return cache.players.contains { cached in
            let c = cached.name.lowercased()
            return c == p || c.contains(p) || p.contains(c)
        }
    }

    private static func extractFirstJSON(_ s: String) -> String? {
        guard let firstBrace = s.firstIndex(of: "{") else { return nil }
        var depth = 0
        var end: String.Index?
        for i in s[firstBrace...].indices {
            let ch = s[i]
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 { end = i; break }
            }
        }
        guard let e = end else { return nil }
        return String(s[firstBrace...e])
    }
}
