import SwiftUI

struct LivePaneView: View {
    @Environment(AppStore.self) private var store
    @State private var audio = AudioCaptureService()

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            )

            ScrollView {
                VStack(spacing: 12) {
                    if !store.partialTranscript.isEmpty && store.liveState == .listening {
                        TranscriptOverlay(text: store.partialTranscript)
                    }

                    ForEach(store.currentSession.statCards.reversed()) { card in
                        StatCardView(card: card)
                    }

                    if store.currentSession.statCards.isEmpty && store.liveState == .idle {
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
        .onDisappear {
            if store.liveState == .listening {
                audio.stop()
                store.liveState = .idle
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
        Task { @MainActor in
            do {
                try await audio.requestPermissions()

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
                        store.liveState = .error(err.localizedDescription)
                    }
                }

                try audio.start()
                store.liveState = .listening
                store.partialTranscript = ""
            } catch let e as AudioError {
                store.liveState = .error(e.localizedDescription)
            } catch {
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

        store.appendTranscript(transcript)
        // Clear partial so next segment's partials don't collide with this finished one
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
            // Keep listening — do not flip state back to idle
        } catch {
            // Swallow per-segment errors so one bad segment doesn't kill listening.
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
