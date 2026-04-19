import SwiftUI

struct ResearchCenterView: View {
    @Environment(AppStore.self) private var store
    @State private var promptText: String = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            )

            HSplitView {
                notesColumn
                chatColumn
            }
        }
        .background(Color.bgBase)
    }

    private var notesColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOTES")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                Text("autosaved")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }

            TextEditor(text: Binding(
                get: { store.currentSession.notes },
                set: { store.updateNotes($0) }
            ))
            .font(Typography.body)
            .foregroundStyle(Color.textPrimary)
            .scrollContentBackground(.hidden)
            .padding(10)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
        }
        .padding(20)
        .frame(minWidth: 340)
        .background(Color.bgBase)
    }

    private var chatColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Q&A · GROUNDED IN MATCH CACHE")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.currentSession.researchMessages) { m in
                        ChatMessageRow(message: m)
                    }
                    if store.currentSession.researchMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ask grounded questions about the match.")
                                .font(Typography.body)
                                .foregroundStyle(Color.textMuted)
                            Text("e.g. \"How many WC goals does Mbappé have?\"")
                                .font(Typography.chip)
                                .foregroundStyle(Color.textSubtle)
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                TextField("Ask a research question…", text: $promptText, onCommit: send)
                    .textFieldStyle(.plain)
                    .font(Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .padding(10)
                    .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(canSend ? Color.live : Color.textSubtle)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(20)
        }
        .frame(minWidth: 340)
        .background(Color.bgBase)
    }

    private var canSend: Bool {
        !isSending && !promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func send() {
        let text = promptText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isSending else { return }
        promptText = ""
        isSending = true
        store.appendResearchMessage(ChatMessage(role: .user, content: text, grounded: false))

        Task {
            let facts = store.matchCache?.facts.joined(separator: "\n- ") ?? ""
            let system = """
            You are a match research assistant. Answer from the verified facts below only.
            If you don't know, say exactly: "I don't have verified data on that."
            Keep answers under 3 sentences.
            """
            let user = """
            Match facts:
            - \(facts)

            Match: \(store.currentSession.title). Question: \(text)
            """
            do {
                let reply = try await store.cactus.complete(system: system, user: user)
                let grounded = !reply.lowercased().contains("don't have verified")
                    && !reply.lowercased().contains("don't have that")
                await MainActor.run {
                    store.appendResearchMessage(ChatMessage(role: .assistant, content: reply, grounded: grounded))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    store.appendResearchMessage(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", grounded: false))
                    isSending = false
                }
            }
        }
    }
}
