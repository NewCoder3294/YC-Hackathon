import SwiftUI

struct ArchiveDetailView: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(matchTitle: session.title, isAirplane: true, latencyMs: nil)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("TRANSCRIPT") {
                        Text(session.transcript.isEmpty ? "—" : session.transcript)
                            .font(Typography.body)
                            .foregroundStyle(Color.textMuted)
                            .textSelection(.enabled)
                    }

                    Divider().background(Color.bbBorder)

                    section("STAT CARDS") {
                        if session.statCards.isEmpty {
                            Text("—").font(Typography.body).foregroundStyle(Color.textSubtle)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(session.statCards) { StatCardView(card: $0) }
                            }
                        }
                    }

                    Divider().background(Color.bbBorder)

                    section("NOTES") {
                        Text(session.notes.isEmpty ? "—" : session.notes)
                            .font(Typography.body)
                            .foregroundStyle(Color.textMuted)
                            .textSelection(.enabled)
                    }

                    Divider().background(Color.bbBorder)

                    section("RESEARCH") {
                        if session.researchMessages.isEmpty {
                            Text("—").font(Typography.body).foregroundStyle(Color.textSubtle)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(session.researchMessages) { ChatMessageRow(message: $0) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(Color.bgBase)
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.sectionHead)
                .foregroundStyle(Color.textSubtle)
            content()
        }
    }
}
