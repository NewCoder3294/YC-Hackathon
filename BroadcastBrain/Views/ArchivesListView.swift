import SwiftUI

/// Archive tab — stores past sessions (transcripts, notes, stat cards).
/// Shows a list on entry; clicking a row opens its read-only detail. Back
/// button returns to the list.
struct ArchivesListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if let id = store.selectedArchiveId,
           let session = store.sessionStore.sessions.first(where: { $0.id == id }) {
            detailView(session: session)
        } else {
            listView
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: "Archive",
                isAirplane: true,
                latencyMs: nil
            )

            HStack(spacing: 10) {
                Text("PAST SESSIONS")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                Text("\(store.sessionStore.sessions.count) total")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.bgRaised)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.bbBorder).frame(height: 1)
            }

            ScrollView {
                VStack(spacing: 10) {
                    if store.sessionStore.sessions.isEmpty {
                        StackCard(kind: .empty) {
                            Text("No sessions yet. Go live and BroadcastBrain will save every match.")
                                .font(Typography.body)
                                .foregroundStyle(Color.textSubtle)
                        }
                    }
                    ForEach(store.sessionStore.sessions) { session in
                        ArchiveEntryCard(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedArchiveId = session.id
                            }
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    private func detailView(session: Session) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { store.selectedArchiveId = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("All sessions")
                            .font(Typography.body)
                    }
                    .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.bgRaised)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.bbBorder).frame(height: 1)
            }

            ArchiveDetailView(session: session)
        }
    }
}

struct ArchiveEntryCard: View {
    let session: Session

    var body: some View {
        StackCard(kind: .stat) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(session.title)
                        .font(Typography.playerName)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                }
                HStack(spacing: 14) {
                    metric(label: "CARDS", value: "\(session.statCards.count)", color: .verified)
                    metric(label: "TRANSCRIPT", value: session.transcript.isEmpty ? "—" : "\(session.transcript.count) chars", color: .textMuted)
                    metric(label: "NOTES", value: session.notes.isEmpty ? "—" : "\(session.notes.split(separator: "\n").count) lines", color: .textMuted)
                    metric(label: "Q&A", value: "\(session.researchMessages.count)", color: .textMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textSubtle)
                }
            }
        }
    }

    private func metric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
            Text(value)
                .font(Typography.statLabel)
                .foregroundStyle(color)
        }
    }
}
