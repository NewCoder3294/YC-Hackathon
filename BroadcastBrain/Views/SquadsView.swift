import SwiftUI

/// Pre-match spotting board. Two columns (one per team), three display modes
/// (Stats / Story / Tactical) that change how every player cell renders.
/// Ported conceptually from reference/frontend/design-handoff/feature-1.
struct SquadsView: View {
    @Environment(AppStore.self) private var store
    @State private var mode: SpottingMode = .stats

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                sport: store.currentSession.match?.sport,
                latencyMs: store.lastLatencyMs
            )

            header

            ZStack {
                DottedGrid()

                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        teamColumn(team: "Argentina", accent: Color(hex: "#7AB8E3"))
                        teamColumn(team: "France", accent: Color(hex: "#D06060"))
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.bgBase)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("SPOTTING BOARD")
                .font(Typography.sectionHead)
                .foregroundStyle(Color.textSubtle)
            Spacer()
            modePicker
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(SpottingMode.allCases) { m in
                Button(action: { mode = m }) {
                    Text(m.label)
                        .font(Typography.chip)
                        .foregroundStyle(mode == m ? Color.textPrimary : Color.textSubtle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mode == m ? Color.bgHover : Color.clear)
                }
                .buttonStyle(.plain)
                if m != SpottingMode.allCases.last {
                    Rectangle().fill(Color.bbBorder).frame(width: 1, height: 16)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func teamColumn(team: String, accent: Color) -> some View {
        let players = (store.matchCache?.players ?? []).filter { $0.team == team }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(accent).frame(width: 10, height: 10)
                Text(team.uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(players.count)")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }

            ForEach(players, id: \.name) { player in
                PlayerCellView(player: player, mode: mode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
