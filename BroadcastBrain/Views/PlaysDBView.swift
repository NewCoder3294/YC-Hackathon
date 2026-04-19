import SwiftUI
import PlayByPlayKit

struct PlaysDBView: View {
    @Environment(AppStore.self) private var store

    @State private var entries: [SavedGameEntry] = []
    @State private var selected: SavedGameEntry?
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: selected?.game.game.shortName ?? "Plays DB · ESPN cache",
                sport: nil,
                latencyMs: nil
            )

            if let sel = selected {
                detailHeader(sel)
                detailView(sel)
            } else {
                listHeader
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .onAppear { reload() }
    }

    // MARK: - List header

    private var listHeader: some View {
        HStack(spacing: 12) {
            Text("SAVED PLAYS")
                .font(Typography.sectionHead)
                .tracking(1.4)
                .foregroundStyle(Color.textSubtle)

            countPill("\(entries.count) GAMES")

            Spacer()

            searchField

            refreshButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSubtle)
            TextField("Search saved games", text: $query)
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
        .padding(.vertical, 6)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
        .frame(width: 240)
    }

    private var refreshButton: some View {
        Button {
            reload()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textMuted)
                .frame(width: 32, height: 30)
                .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Re-scan saved games")
    }

    private func countPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.textSubtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bbBorder, lineWidth: 1))
    }

    // MARK: - List body

    private var filtered: [SavedGameEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.game.game.shortName.lowercased().contains(q)
                || $0.leagueKey.lowercased().contains(q)
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if entries.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    noMatchState
                } else {
                    ForEach(filtered) { entry in
                        SavedGameRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { selected = entry }
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.textSubtle)
            Text("No saved games yet")
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
            Text("Start streaming a game from the Plays tab — each play is cached here for offline scrubbing.")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }

    private var noMatchState: some View {
        Text("No saved games match ‘\(query)’")
            .font(Typography.chip)
            .foregroundStyle(Color.textSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }

    // MARK: - Detail

    private func detailHeader(_ entry: SavedGameEntry) -> some View {
        HStack(spacing: 12) {
            Button { selected = nil } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("ALL SAVED GAMES")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            leagueBadge(entry.leagueKey)

            Text(entry.game.game.shortName)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)

            Text(entry.game.game.statusDetail)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)

            Spacer()

            HStack(spacing: 6) {
                Text("\(entry.game.totalPlays)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.verified)
                Text("PLAYS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.textSubtle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private func detailView(_ entry: SavedGameEntry) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                ForEach(entry.game.periods, id: \.number) { period in
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(period.plays) { play in
                                PlayRow(play: play, compact: entry.game)
                            }
                        }
                        .padding(.bottom, 8)
                    } header: {
                        HStack(spacing: 10) {
                            Text(period.displayValue ?? "Period \(period.number)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(Color.textSubtle)
                            Rectangle().fill(Color.bbBorder).frame(height: 1)
                            Text("\(period.plays.count)")
                                .font(Typography.chip)
                                .foregroundStyle(Color.textSubtle)
                        }
                        .padding(.vertical, 6)
                        .background(Color.bgBase)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - League badge

    private func leagueBadge(_ key: String) -> some View {
        let accent = PlaysDBView.leagueAccent(key)
        return Text(key.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(accent.opacity(0.3), lineWidth: 1))
    }

    static func leagueAccent(_ key: String) -> Color {
        switch key.lowercased() {
        case let k where k.contains("nba"):  return Color(hex: "#E87A00")
        case let k where k.contains("mlb"):  return Color(hex: "#3B82F6")
        case let k where k.contains("nfl"):  return Color(hex: "#8B5CF6")
        case let k where k.contains("nhl"):  return Color(hex: "#22C55E")
        case let k where k.contains("mls"),
             let k where k.contains("epl"),
             let k where k.contains("uefa"): return Color.verified
        default:                              return Color.textMuted
        }
    }

    private func reload() {
        entries = store.playByPlayStore.listSavedGames()
    }
}

// MARK: - Saved game row

private struct SavedGameRow: View {
    let entry: SavedGameEntry

    @State private var hovering = false

    private var accent: Color { PlaysDBView.leagueAccent(entry.leagueKey) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 3)

            // League badge
            Text(entry.leagueKey.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(accent)
                .frame(width: 52, alignment: .center)
                .padding(.vertical, 4)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(accent.opacity(0.25), lineWidth: 1))
                .padding(.leading, 14)
                .padding(.trailing, 14)

            // Matchup
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.game.game.shortName)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(entry.game.game.statusDetail)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                    if !entry.game.game.awayScore.isEmpty, !entry.game.game.homeScore.isEmpty {
                        Text("·")
                            .font(Typography.chip)
                            .foregroundStyle(Color.textSubtle)
                        Text("\(entry.game.game.awayScore)–\(entry.game.game.homeScore)")
                            .font(Typography.chip)
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }

            Spacer()

            // Play count hero stat
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    Text("\(entry.game.totalPlays)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.verified)
                    Text("PLAYS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.textSubtle)
                }
                Text(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hovering ? Color.textPrimary : Color.textSubtle)
                .padding(.leading, 12)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(hovering ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}
