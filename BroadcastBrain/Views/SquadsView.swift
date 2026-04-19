import SwiftUI

/// Pre-match spotting board. Two columns (one per team), three display modes
/// (Stats / Story / Tactical) that change how every player cell renders.
struct SquadsView: View {
    @Environment(AppStore.self) private var store
    @State private var mode: SpottingMode = .stats
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            )

            header

            ZStack {
                DottedGrid()

                ScrollView {
                    HStack(alignment: .top, spacing: 16) {
                        teamColumn(team: "Argentina", accent: Color(hex: "#7AB8E3"))
                        teamColumn(team: "France",    accent: Color(hex: "#D06060"))
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.bgBase)
    }

    // MARK: - Header (mode picker + search)

    private var header: some View {
        HStack(spacing: 14) {
            Text("SPOTTING BOARD")
                .font(Typography.sectionHead)
                .tracking(1.4)
                .foregroundStyle(Color.textSubtle)

            countPill

            Spacer()

            searchField
                .frame(width: 220)

            modePicker
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private var countPill: some View {
        let total = store.matchCache?.players.count ?? 0
        return Text("\(total) PLAYERS")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.textSubtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bbBorder, lineWidth: 1))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSubtle)
            TextField("Filter players", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSubtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(SpottingMode.allCases) { m in
                Button(action: { mode = m }) {
                    Text(m.label)
                        .font(Typography.chip)
                        .tracking(0.5)
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

    // MARK: - Team column

    private func teamColumn(team: String, accent: Color) -> some View {
        let all = (store.matchCache?.players ?? []).filter { $0.team == team }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty
            ? all
            : all.filter { $0.name.lowercased().contains(q) || $0.position.lowercased().contains(q) }

        return VStack(alignment: .leading, spacing: 10) {
            teamHeader(team: team, accent: accent, total: all.count, shown: filtered.count)

            if filtered.isEmpty {
                emptyColumn
            } else {
                ForEach(filtered, id: \.name) { player in
                    PlayerCellView(player: player, mode: mode)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func teamHeader(team: String, accent: Color, total: Int, shown: Int) -> some View {
        VStack(spacing: 0) {
            // Color strip at top
            Rectangle()
                .fill(accent)
                .frame(height: 3)

            HStack(spacing: 10) {
                Text(team.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.textPrimary)

                Text("\(shown)\(shown == total ? "" : "/\(total)")")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bbBorder, lineWidth: 1))

                Spacer()

                SportradarBadge()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.bgRaised)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var emptyColumn: some View {
        Text("No players match ‘\(query)’")
            .font(Typography.chip)
            .foregroundStyle(Color.textSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }
}
