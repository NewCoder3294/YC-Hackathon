import SwiftUI
import AVFoundation
import AppKit

struct LivePaneView: View {
    @Environment(AppStore.self) private var store
    @State private var audio = AudioCaptureService()
    @State private var permState: PermissionState = .unknown
    @State private var showEndConfirm: Bool = false
    @State private var whisperArmed: Bool = false
    @State private var recordingStartedAt: Date?
    /// Approximate audio level for waveform display (RMS from last batch).
    @State private var audioLevel: Float = 0

    enum PermissionState: Equatable {
        case unknown
        case ok
        case micDenied

        var bannerText: String? {
            switch self {
            case .unknown, .ok: return nil
            case .micDenied: return "Microphone access is off. Enable in System Settings → Privacy & Security → Microphone."
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                StatusBarView(
                    matchTitle: store.currentSession.title,
                    sport: store.currentSession.match?.sport,
                    latencyMs: store.lastLatencyMs
                )

                HSplitView {
                    // Left: audio capture status
                    audioColumn

                    // Right: stat cards surfaced by Gemma
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

    // MARK: - End-match overlay

    private var endConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { showEndConfirm = false }
                }

            VStack(alignment: .leading, spacing: 0) {
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

                VStack(alignment: .leading, spacing: 10) {
                    row(label: "STAT CARDS", value: "\(store.currentSession.statCards.filter { $0.kind == .stat }.count)", valueColor: .verified)
                    row(label: "WHISPERS",   value: "\(store.currentSession.statCards.filter { $0.kind == .whisper }.count)", valueColor: .esoteric)
                    Divider().background(Color.bbBorder).padding(.vertical, 4)
                    Text("Saved to Archive · accessible any time.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                }
                .padding(20)

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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.bbBorder, lineWidth: 1))
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

    // MARK: - Audio capture column (replaces transcript column)

    private var audioColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AUDIO INPUT")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                if store.liveState == .listening {
                    HStack(spacing: 6) {
                        ListeningDot()
                        Text("CAPTURING")
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
                .help("Clear stat cards for this session")
                .disabled(store.currentSession.statCards.isEmpty)
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

            // Audio status panel
            VStack(alignment: .leading, spacing: 18) {
                if store.liveState != .listening {
                    audioIdleState
                } else {
                    audioActiveState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
        }
        .padding(20)
        .frame(minWidth: 360)
        .background(Color.bgBase)
    }

    private var audioIdleState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.live.opacity(0.4), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.live)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("GEMMA 4 AUDIO MODE")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.textPrimary)
                    Text(permState.bannerText != nil
                         ? "Grant microphone permission above first."
                         : "Tap the mic to start. Gemma 4 hears the broadcast directly — no transcription step.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().background(Color.bbBorder.opacity(0.5))

            VStack(alignment: .leading, spacing: 8) {
                Text("HOW IT WORKS")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                VStack(alignment: .leading, spacing: 6) {
                    audioInfoRow(icon: "mic.fill", text: "Mic captured → 16 kHz mono PCM")
                    audioInfoRow(icon: "waveform", text: "Energy VAD detects utterance boundaries")
                    audioInfoRow(icon: "cpu", text: "Utterance WAV + ESPN plays → Gemma 4 inference")
                    audioInfoRow(icon: "bubble.left.fill", text: "Stat card surfaces on the right")
                }
            }
        }
    }

    private var audioActiveState: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.live.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(Color.live.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.live)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("LISTENING")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.live)
                        .tracking(0.8)
                    Text("Audio piped directly to Gemma 4")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                }
            }

            Divider().background(Color.bbBorder.opacity(0.5))

            VStack(alignment: .leading, spacing: 10) {
                Text("PIPELINE")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                audioInfoRow(icon: "mic.fill", text: "AVAudioEngine → 16 kHz PCM")
                audioInfoRow(icon: "waveform", text: "Energy VAD → utterance boundary")
                audioInfoRow(icon: "cpu", text: "WAV + live plays → Gemma 4 audio inference")
                audioInfoRow(icon: "sparkles", text: "Stat card or whisper surfaces on the right")
            }

            if let path = store.latestUtterancePath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST UTTERANCE")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(10)
                .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
            }
        }
    }

    private func audioInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.live.opacity(0.7))
                .frame(width: 14)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Color.textMuted)
        }
    }

    // MARK: - Stat cards column (unchanged)

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
                            Text("Cards surface here as you broadcast.")
                                .font(Typography.body)
                                .foregroundStyle(Color.textMuted)
                            Text("Gemma 4 hears the audio and game context — stat cards and whispers appear automatically.")
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

    // MARK: - Banners

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
                    Button("Open Mic Settings") {
                        openSettings(section: "Privacy_Microphone")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Broadcast console

    private var broadcastConsole: some View {
        let isListening = store.liveState == .listening
        let statCount = store.currentSession.statCards.filter { $0.kind == .stat }.count
        let whisperCount = store.currentSession.statCards.filter { $0.kind == .whisper }.count

        return HStack(alignment: .center, spacing: 28) {
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

            PressToTalkButton(
                isListening: isListening,
                onToggle: matchButtonTapped
            )

            Spacer()

            sessionStatsBox(stats: statCount, whispers: whisperCount)
                .frame(minWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.bgRaised.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private func sessionStatsBox(stats: Int, whispers: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SESSION")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .tracking(1.4)

            Divider().background(Color.bbBorder.opacity(0.5))

            compactMetric(systemImage: "checkmark.seal.fill", tint: .verified, label: "STATS", value: "\(stats)")
            compactMetric(systemImage: "bubble.left.and.text.bubble.right.fill", tint: .esoteric, label: "WHISPERS", value: "\(whispers)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
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
        let m = secs / 60; let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Whisper button

    private var whisperButton: some View {
        let isListening = store.liveState == .listening

        return VStack(spacing: 8) {
            Button(action: { if isListening { whisperArmed.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(whisperArmed ? Color.esoteric : Color.bgRaised)
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(whisperArmed ? Color.esoteric : Color.bbBorder, lineWidth: whisperArmed ? 3 : 1)
                        .frame(width: 56, height: 56)
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(whisperArmed ? Color.bgBase : (isListening ? Color.esoteric : Color.textSubtle))
                }
            }
            .buttonStyle(.plain)
            .disabled(!isListening)

            Text(whisperArmed ? "WHISPER ARMED" : "BTW · WHISPER")
                .font(Typography.chip)
                .foregroundStyle(whisperArmed ? Color.esoteric : Color.textSubtle)
                .tracking(0.5)

            agentWhisperChip
            cactusSourcePill
            whisperSkipFooter
        }
    }

    private var cactusSourcePill: some View {
        let healthy = store.cactus.isHealthy
        return Text(store.cactus.sourceLabel)
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(healthy ? Color.textMuted : Color.esoteric)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(healthy ? Color.bbBorder : Color.esoteric.opacity(0.6), lineWidth: 1))
            .help(healthy
                  ? "Cactus model loaded and answering."
                  : "Cactus is not available — install the Gemma weights.")
    }

    @ViewBuilder
    private var whisperSkipFooter: some View {
        if let reason = store.lastWhisperSkip, store.whisperEngine.isRunning {
            Text(reason.displayText)
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .lineLimit(2)
                .frame(maxWidth: 140)
                .multilineTextAlignment(.center)
        }
    }

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
            .background((running ? Color.verified.opacity(0.12) : Color.bgSubtle), in: Capsule())
            .overlay(Capsule().stroke(running ? Color.verified.opacity(0.5) : Color.bbBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isListening)
        .opacity(isListening ? 1 : 0.5)
        .help("Auto-whisper: every 30 seconds Gemma surfaces a stat useful for the next play.")
    }

    private func toggleAgentWhisper() {
        guard store.liveState == .listening else { return }
        if store.whisperEngine.isRunning { store.whisperEngine.stop() }
        else { store.whisperEngine.start() }
    }

    // MARK: - Mic tap routing

    private func matchButtonTapped() {
        if store.liveState == .listening { showEndConfirm = true }
        else { startListening() }
    }

    private func endMatch() {
        audio.stop()
        whisperArmed = false
        recordingStartedAt = nil
        store.liveState = .idle
        store.whisperEngine.stop()
        store.speech.stop()
        store.sessionStore.save(store.currentSession)

        let finishedId = store.currentSession.id
        let hadContent = !store.currentSession.statCards.isEmpty
        if hadContent { store.newSessionKeepingCurrentMatch() }

        store.selectedSurface = .archive
        store.selectedArchiveId = finishedId
    }

    private func clearSession() {
        store.currentSession.transcript = ""
        store.currentSession.statCards = []
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
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.esoteric.opacity(0.5), lineWidth: 1))
    }

    private func refreshPermissionState() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micBad = micStatus == .denied || micStatus == .restricted
        permState = micBad ? .micDenied : (micStatus == .authorized ? .ok : .unknown)
    }

    // MARK: - Start / stop listening

    private func startListening() {
        store.liveState = .processing

        Task { @MainActor in
            do {
                try await audio.requestPermissions()
                refreshPermissionState()

                // Route each VAD-detected utterance to Gemma audio inference
                audio.onUtterance = { path in
                    Task { @MainActor in
                        guard store.liveState == .listening else { return }
                        // Echo suppression: don't process utterances while TTS is speaking
                        guard !store.speech.isEchoLikely else { return }
                        store.latestUtterancePath = path
                        await handleAudioSegment(path: path)
                    }
                }
                audio.onError = { err in
                    Task { @MainActor in
                        store.liveState = .error(err.localizedDescription)
                    }
                }

                try audio.start()
                store.liveState = .listening
                if recordingStartedAt == nil { recordingStartedAt = Date() }
                store.whisperEngine.start()
            } catch let e as AudioError {
                refreshPermissionState()
                store.liveState = .error(e.localizedDescription)
            } catch {
                refreshPermissionState()
                store.liveState = .error(error.localizedDescription)
            }
        }
    }

    private func stopListening() {
        audio.stop()
        store.liveState = .idle
        recordingStartedAt = nil
        store.whisperEngine.stop()
        store.speech.stop()
    }

    // MARK: - Gemma audio inference

    @MainActor
    private func handleAudioSegment(path: String) async {
        let forceWhisper = whisperArmed
        if forceWhisper { whisperArmed = false }

        let livePlays = store.playByPlayStore.plays
        let compact = store.playByPlayStore.currentCompact
        let filteredPlays = PlayContextFilter.filter(plays: livePlays, query: nil, compact: compact)
        let playsBlock = WhisperEngine.renderPlays(filteredPlays, compact: compact)
        let havePlays = !playsBlock.isEmpty

        let cache = store.matchCacheForCurrentSession
        let facts = cache?.facts.prefix(8).joined(separator: "\n- ") ?? ""
        let haveFacts = !facts.isEmpty
        let haveGrounding = havePlays || haveFacts

        if forceWhisper && !haveGrounding {
            let isLoading = store.playByPlayStore.isStreaming
            let msg = isLoading
                ? "The live feed is still loading — give it a few seconds and try again."
                : "No live feed is attached to this session, so I can't answer that."
            let card = StatCard(kind: .whisper, player: "Agent", rawTranscript: "", latencyMs: 0, answer: msg)
            store.appendStatCard(card)
            store.speech.speak(msg)
            return
        }

        let system = forceWhisper ? Self.whisperSystemPrompt : Self.audioSystemPrompt
        let factsBlock = haveFacts ? "- \(facts)" : "(no data)"
        let playsRendered = havePlays ? playsBlock : "(no data — no live feed attached)"
        let user = """
        Match: \(store.currentSession.title).

        Recent plays (most recent last, \(filteredPlays.count) of \(livePlays.count) from ESPN feed):
        \(playsRendered)

        Match facts:
        \(factsBlock)
        """

        let started = Date()
        do {
            let reply = try await store.cactus.complete(system: system, user: user, audioPath: path)
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            store.lastLatencyMs = latency
            store.inferenceWarning = nil

            if let card = parseStatCard(reply, latencyMs: latency) {
                if card.kind == .whisper && !haveGrounding { return }
                store.appendStatCard(card)
                if card.kind == .whisper, let answer = card.answer, !answer.isEmpty {
                    store.speech.speak(answer)
                }
            } else if forceWhisper, haveGrounding {
                if let fallback = Self.proseFallbackAnswer(from: reply) {
                    let card = StatCard(kind: .whisper, player: "Agent", rawTranscript: "", latencyMs: latency, answer: fallback)
                    store.appendStatCard(card)
                    store.speech.speak(fallback)
                }
            }
        } catch {
            store.inferenceWarning = "Inference failed: \(error.localizedDescription)"
        }
    }

    // MARK: - System prompts

    private static let audioSystemPrompt = """
    You are a sports broadcast agent. You receive audio of the commentator and the ESPN \
    play-by-play feed. Listen to what the commentator says and the game context, then route \
    to one of two output kinds:

    1) If the broadcaster described a live moment (goal, foul, booking, sub): return a STAT CARD:
       {"type":"stat","player":"…","stat_value":"…","context_line":"…","source":"ESPN play-by-play","confidence":"high"}

    2) If the broadcaster asked a question or requested context: return a WHISPER ANSWER:
       {"type":"whisper","player":"…","answer":"<1-2 sentence grounded answer>","source":"ESPN play-by-play"}

    Ground every answer in the plays data below. Return ONLY a single JSON object.
    If nothing actionable can be said: {"no_verified_data":true}.
    Do NOT invent numbers.
    """

    private static let whisperSystemPrompt = """
    You are a live broadcast stats whisperer. The commentator explicitly requested a stat \
    whisper. Listen to the audio and return a grounded whisper answer from the play data.

    Return STRICTLY ONE JSON object:
    {"type":"whisper","player":"…","answer":"<1-2 sentence grounded answer>","source":"ESPN play-by-play"}

    If nothing useful can be derived from the plays: {"no_verified_data":true}.
    Do NOT invent numbers. Only use facts present in the plays payload.
    """

    // MARK: - JSON parsing (stat card)

    private func parseStatCard(_ json: String, latencyMs: Int) -> StatCard? {
        guard let jsonBlock = Self.extractFirstJSON(json),
              let data = jsonBlock.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if obj["no_verified_data"] as? Bool == true { return nil }

        let typeStr = obj["type"] as? String ?? "stat"

        if typeStr == "whisper" {
            let answer = (obj["answer"] as? String) ?? ""
            let player = (obj["player"] as? String) ?? "Whisper"
            guard !answer.isEmpty else { return nil }
            return StatCard(kind: .whisper, player: player, rawTranscript: "", latencyMs: latencyMs, answer: answer)
        }

        guard
            let player = obj["player"] as? String,
            let stat = obj["stat_value"] as? String,
            let ctx = obj["context_line"] as? String
        else { return nil }

        if let cache = store.matchCacheForCurrentSession,
           !Self.playerIsInCache(player, cache: cache) { return nil }

        let src = obj["source"] as? String ?? "ESPN play-by-play"
        return StatCard(kind: .stat, player: player, statValue: stat, contextLine: ctx, source: src, rawTranscript: "", latencyMs: latencyMs)
    }

    private static func playerIsInCache(_ player: String, cache: MatchCache) -> Bool {
        let p = player.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return false }
        return cache.players.contains { c in
            let n = c.name.lowercased()
            return n == p || n.contains(p) || p.contains(n)
        }
    }

    private static func extractFirstJSON(_ s: String) -> String? {
        guard let firstBrace = s.firstIndex(of: "{") else { return nil }
        var depth = 0; var end: String.Index?
        for i in s[firstBrace...].indices {
            let ch = s[i]
            if ch == "{" { depth += 1 }
            else if ch == "}" { depth -= 1; if depth == 0 { end = i; break } }
        }
        guard let e = end else { return nil }
        return String(s[firstBrace...e])
    }

    // MARK: - Prose fallback

    static func proseFallbackAnswer(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let paragraphs = trimmed.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidate = paragraphs.first(where: { !isMetaChatter($0) }) ?? paragraphs.first
        guard var answer = candidate else { return nil }
        answer = answer
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if answer.hasPrefix("{") { return nil }
        if let terminator = answer.firstIndex(where: { ".!?".contains($0) }) {
            answer = String(answer[..<answer.index(after: terminator)])
        }
        if answer.count > 220 { answer = String(answer.prefix(220)) + "…" }
        let final = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty, !isRefusal(final) else { return nil }
        return final
    }

    static func isMetaChatter(_ paragraph: String) -> Bool {
        let lower = paragraph.lowercased()
        return ["please provide", "i need more information", "as an ai",
                "i am a large language model", "i'm sorry", "okay, let's"]
            .contains(where: { lower.hasPrefix($0) })
    }

    static func isRefusal(_ sentence: String) -> Bool {
        let lower = sentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let firstPerson = lower.hasPrefix("i ") || lower.hasPrefix("i'") || lower.hasPrefix("my ")
        guard firstPerson else { return false }
        return ["verified data", "don't have", "do not have", "don't know", "do not know",
                "can't answer", "cannot answer", "unable to", "have no information",
                "have no data", "am not sure", "apologize"]
            .contains(where: { lower.contains($0) })
    }
}
