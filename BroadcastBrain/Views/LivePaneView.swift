import SwiftUI
import AVFoundation
import Speech
import AppKit

struct LivePaneView: View {
    @Environment(AppStore.self) private var store
    @State private var audio = AudioCaptureService()
    @State private var permState: PermissionState = .unknown

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
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            )

            ScrollView {
                VStack(spacing: 12) {
                    if let banner = permState.bannerText {
                        permissionBanner(banner)
                    }

                    if !store.partialTranscript.isEmpty && store.liveState == .listening {
                        TranscriptOverlay(text: store.partialTranscript)
                    }

                    ForEach(store.currentSession.statCards.reversed()) { card in
                        StatCardView(card: card)
                    }

                    if store.currentSession.statCards.isEmpty && store.liveState == .idle && permState != .micDenied && permState != .speechDenied && permState != .bothDenied {
                        StackCard(kind: .empty) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tap the mic to go live.")
                                    .font(Typography.body)
                                    .foregroundStyle(Color.textMuted)
                                Text("BroadcastBrain will listen continuously and surface a stat card when it hears something worth surfacing.")
                                    .font(Typography.chip)
                                    .foregroundStyle(Color.textSubtle)
                                Text("Try: \"Mbappé just scored his second\" or \"Messi steps up for the penalty\"")
                                    .font(Typography.chip)
                                    .foregroundStyle(Color.textSubtle)
                            }
                        }
                    }

                    if case .error(let msg) = store.liveState {
                        StackCard(kind: .counter) {
                            Text("Error: \(msg)")
                                .font(Typography.body)
                                .foregroundStyle(Color.live)
                        }
                    }
                }
                .padding(20)
            }

            Divider().background(Color.bbBorder)

            PressToTalkButton(
                isListening: store.liveState == .listening,
                onToggle: toggleListening
            )
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .task { refreshPermissionState() }
        .onDisappear {
            if store.liveState == .listening {
                audio.stop()
                store.liveState = .idle
            }
        }
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
                        if store.liveState == .listening {
                            store.partialTranscript = partial
                        }
                    }
                }
                audio.onSegment = { segment in
                    Task { @MainActor in
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
        store.liveState = .idle
        store.partialTranscript = ""
    }

    @MainActor
    private func handleSegment(_ segment: String) async {
        let transcript = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        print("[live] segment: \(transcript)")

        store.appendTranscript(transcript)
        store.partialTranscript = ""

        let started = Date()

        let facts = store.matchCache?.facts.prefix(8).joined(separator: "\n- ") ?? ""
        let system = """
        You are a sports stat assistant for a live football broadcaster.
        Answer ONLY from the verified match facts below. If no fact matches, return JSON {"no_verified_data":true}.
        Otherwise return JSON {"player":..., "stat_value":..., "context_line":..., "source":"Sportradar", "confidence":"high"|"medium"}.
        Return ONLY JSON, no other text.
        """
        let user = """
        Match facts:
        - \(facts)

        Commentator just said: "\(transcript)". Match: \(store.currentSession.title).
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
        guard
            let player = obj["player"] as? String,
            let stat = obj["stat_value"] as? String,
            let ctx = obj["context_line"] as? String
        else { return nil }
        let src = obj["source"] as? String ?? "Sportradar"
        return StatCard(
            player: player,
            statValue: stat,
            contextLine: ctx,
            source: src,
            rawTranscript: raw,
            latencyMs: latencyMs
        )
    }
}
