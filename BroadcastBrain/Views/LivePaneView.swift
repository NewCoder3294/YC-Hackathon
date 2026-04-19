import SwiftUI
import AVFoundation
import Speech
import AppKit

struct LivePaneView: View {
    @Environment(AppStore.self) private var store
    @State private var audio = AudioCaptureService()
    @State private var permState: PermissionState = .unknown
    @State private var debounceTask: Task<Void, Never>?
    @State private var lastHandledSegment: String = ""
    @State private var showEndConfirm: Bool = false
    @State private var whisperArmed: Bool = false

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

                HStack(alignment: .center, spacing: 32) {
                    Spacer()
                    PressToTalkButton(
                        isListening: store.liveState == .listening,
                        onToggle: matchButtonTapped
                    )
                    whisperButton
                    Spacer()
                }
                .padding(.vertical, 20)
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
                            Text(permState.bannerText != nil
                                 ? "Grant permissions above, then tap the mic."
                                 : "Tap the mic to start listening. Everything you say will appear here live.")
                                .font(Typography.body)
                                .foregroundStyle(Color.textSubtle)
                        }

                        if !store.currentSession.transcript.isEmpty {
                            ForEach(Array(store.currentSession.transcript.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                                Text(String(line))
                                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !store.partialTranscript.isEmpty && store.liveState == .listening {
                            Text(store.partialTranscript)
                                .font(.system(size: 16, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.textMuted)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("__partial__")
                        }

                        Color.clear.frame(height: 1).id("__bottom__")
                    }
                    .padding(14)
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
        lastHandledSegment = ""
        whisperArmed = false
        store.liveState = .idle
        store.partialTranscript = ""

        // 2. Save any final transcript progress
        store.sessionStore.save(store.currentSession)

        // 3. Capture id, prepare fresh session so next match is clean
        let finishedId = store.currentSession.id
        let hadContent = !store.currentSession.transcript.isEmpty
            || !store.currentSession.statCards.isEmpty

        if hadContent {
            store.newSession()
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
                        store.partialTranscript = partial

                        // Debounce: if partial stays the same for 1.2s, treat it
                        // as a complete segment and ship to Gemma. Protects us
                        // from SFSpeechRecognizer taking 3-5+ seconds to fire isFinal.
                        debounceTask?.cancel()
                        let snapshot = partial
                        debounceTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            guard !Task.isCancelled else { return }
                            guard store.liveState == .listening else { return }
                            guard store.partialTranscript == snapshot, !snapshot.isEmpty else { return }
                            guard snapshot != lastHandledSegment else { return }
                            lastHandledSegment = snapshot
                            await handleSegment(snapshot)
                        }
                    }
                }
                audio.onSegment = { segment in
                    Task { @MainActor in
                        debounceTask?.cancel()
                        guard segment != lastHandledSegment else { return }
                        lastHandledSegment = segment
                        await handleSegment(segment)
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
        lastHandledSegment = ""
        store.liveState = .idle
        store.partialTranscript = ""
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

        let facts = store.matchCache?.facts.prefix(8).joined(separator: "\n- ") ?? ""
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

        Answer ONLY from the verified match facts below. If no fact matches, return
        {"no_verified_data":true}. Return ONLY JSON, no other text.
        """
        // Prefix [BTW] so both Gemma (via prompt directive) and MockResponder
        // (via substring detection) force whisper routing.
        let utterance = forceWhisper ? "[BTW] \(transcript)" : transcript
        let user = """
        Match facts:
        - \(facts)

        Commentator just said: "\(utterance)". Match: \(store.currentSession.title).
        """

        do {
            let reply = try await store.cactus.complete(system: system, user: user)
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            store.lastLatencyMs = latency

            if let card = parseStatCard(reply, raw: transcript, latencyMs: latency) {
                store.appendStatCard(card)
            }
        } catch {
            print("Gemma error on segment '\(transcript)': \(error)")
        }
    }

    private func parseStatCard(_ json: String, raw: String, latencyMs: Int) -> StatCard? {
        guard let data = json.data(using: .utf8),
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
}
