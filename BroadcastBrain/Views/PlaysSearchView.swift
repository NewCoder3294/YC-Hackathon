import SwiftUI
import PlayByPlayKit

struct PlaysSearchView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var pbp = store.playByPlayStore

        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: "Plays · ESPN feed",
                isAirplane: false,
                latencyMs: nil
            )

            header(pbp: pbp)

            if pbp.selectedGame != nil {
                PlaysStreamView()
            } else {
                scoreboard(pbp: pbp)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .task {
            if pbp.games.isEmpty && pbp.selectedGame == nil {
                await pbp.loadLiveGames()
            }
        }
    }

    // MARK: - Header

    private func header(pbp: PlayByPlayStore) -> some View {
        HStack(spacing: 12) {
            leaguePicker(pbp: pbp)
            searchField(pbp: pbp)
            refreshButton(pbp: pbp)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private func leaguePicker(pbp: PlayByPlayStore) -> some View {
        Menu {
            ForEach(pbp.leagues, id: \.key) { league in
                Button(league.displayName) {
                    pbp.selectedLeague = league
                    pbp.games = []
                    Task { await pbp.loadLiveGames() }
                }
            }
        } label: {
            LeagueDropdownLabel(name: pbp.selectedLeague.displayName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func searchField(pbp: PlayByPlayStore) -> some View {
        SearchFieldRow(
            text: Binding(
                get: { pbp.searchText },
                set: { pbp.searchText = $0 }
            )
        )
    }

    private func refreshButton(pbp: PlayByPlayStore) -> some View {
        Button {
            Task { await pbp.loadLiveGames() }
        } label: {
            Group {
                if pbp.loadingGames {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                }
            }
            .frame(width: 32, height: 30)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.bbBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Refresh live games")
    }

    // MARK: - Scoreboard

    private func scoreboard(pbp: PlayByPlayStore) -> some View {
        ScrollView {
            LazyVStack(spacing: 18, pinnedViews: [.sectionHeaders]) {
                if let err = pbp.gamesError {
                    errorBanner(err)
                }

                let grouped = GameGroup.group(pbp.filteredGames)

                if grouped.isEmpty && !pbp.loadingGames {
                    emptyState(leagueName: pbp.selectedLeague.displayName,
                               hasQuery: !pbp.searchText.isEmpty)
                }

                ForEach(grouped, id: \.status) { bucket in
                    Section {
                        VStack(spacing: 8) {
                            ForEach(bucket.games) { game in
                                GameRow(game: game)
                                    .contentShape(Rectangle())
                                    .onTapGesture { pbp.startStreaming(game) }
                            }
                        }
                    } header: {
                        sectionHeader(bucket)
                    }
                }
            }
            .padding(20)
        }
    }

    private func sectionHeader(_ bucket: GameGroup) -> some View {
        HStack(spacing: 10) {
            if bucket.status == .live {
                LiveDot()
            }
            Text(bucket.status.label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(bucket.status == .live ? Color.live : Color.textSubtle)
            Rectangle().fill(Color.bbBorder).frame(height: 1)
            Text("\(bucket.games.count)")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
        }
        .padding(.vertical, 6)
        .background(Color.bgBase)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.live)
            Text(text)
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.live.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.live.opacity(0.3), lineWidth: 1))
    }

    private func emptyState(leagueName: String, hasQuery: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: hasQuery ? "magnifyingglass" : "sportscourt")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.textSubtle)
            Text(hasQuery ? "No matches" : "No live games")
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
            Text(hasQuery
                 ? "Try a different team name or switch leagues."
                 : "\(leagueName) has no games in progress. Check back later or refresh.")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }
}

// MARK: - Grouping

enum GameStatus: Int, CaseIterable {
    case live, scheduled, final, other

    var label: String {
        switch self {
        case .live:      return "LIVE NOW"
        case .scheduled: return "UPCOMING"
        case .final:     return "COMPLETED"
        case .other:     return "OTHER"
        }
    }

    static func from(_ raw: String) -> GameStatus {
        let s = raw.lowercased()
        if s.contains("in progress") || s.contains("halftime") || s.contains("delay") { return .live }
        if s.contains("scheduled") || s.contains("pre") || s.contains("upcoming") { return .scheduled }
        if s.contains("final") || s.contains("full time") || s.contains("end of") { return .final }
        return .other
    }
}

struct GameGroup {
    let status: GameStatus
    let games: [Game]

    static func group(_ games: [Game]) -> [GameGroup] {
        var byStatus: [GameStatus: [Game]] = [:]
        for g in games {
            byStatus[GameStatus.from(g.status), default: []].append(g)
        }
        return GameStatus.allCases.compactMap { s in
            guard let list = byStatus[s], !list.isEmpty else { return nil }
            return GameGroup(status: s, games: list)
        }
    }
}

// MARK: - Row

private struct GameRow: View {
    let game: Game
    @State private var hovering = false

    private var status: GameStatus { GameStatus.from(game.status) }

    private var homeWin: Bool {
        guard let h = Int(game.homeScore), let a = Int(game.awayScore) else { return false }
        return h > a
    }

    private var awayWin: Bool {
        guard let h = Int(game.homeScore), let a = Int(game.awayScore) else { return false }
        return a > h
    }

    private var accentColor: Color {
        switch status {
        case .live: return Color.live
        case .scheduled: return Color.esoteric
        case .final: return Color.verified
        case .other: return Color.bbBorder
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Accent stripe
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            // Status pill column (fixed width)
            statusPill
                .frame(width: 90, alignment: .leading)
                .padding(.leading, 14)

            // Matchup (fixed width)
            HStack(spacing: 8) {
                Text(awayAbbr)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(awayWin && status == .final ? Color.textPrimary : Color.textMuted)
                Text("@")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                Text(homeAbbr)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(homeWin && status == .final ? Color.textPrimary : Color.textMuted)
            }
            .frame(width: 160, alignment: .leading)

            // Teams + score
            VStack(alignment: .leading, spacing: 3) {
                teamLine(name: game.awayTeam, score: game.awayScore, isWinner: awayWin)
                teamLine(name: game.homeTeam, score: game.homeScore, isWinner: homeWin)
            }

            Spacer()

            // Period / detail
            Text(game.period.isEmpty ? game.statusDetail : game.period)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .lineLimit(1)

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

    // MARK: sub-views

    private var awayAbbr: String { game.awayTeamAbbr ?? String(game.awayTeam.prefix(3)).uppercased() }
    private var homeAbbr: String { game.homeTeamAbbr ?? String(game.homeTeam.prefix(3)).uppercased() }

    @ViewBuilder
    private var statusPill: some View {
        switch status {
        case .live:
            HStack(spacing: 5) {
                LiveDot()
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.live)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.live.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.live.opacity(0.35), lineWidth: 1))
        case .scheduled:
            pill("UPCOMING", color: .esoteric)
        case .final:
            pill("FINAL", color: .textSubtle)
        case .other:
            pill(game.status.uppercased(), color: .textSubtle)
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.25), lineWidth: 1))
    }

    private func teamLine(name: String, score: String, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 12, weight: isWinner ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isWinner ? Color.textPrimary : Color.textMuted)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(score)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isWinner ? Color.textPrimary : Color.textMuted)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .frame(maxWidth: 280)
    }
}

private struct LeagueDropdownLabel: View {
    let name: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text("LEAGUE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.textSubtle)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.bgBase, in: RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.bbBorder, lineWidth: 1))

            Text(name.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.textPrimary)

            Rectangle()
                .fill(Color.bbBorder)
                .frame(width: 1, height: 16)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(hovering ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct SearchFieldRow: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSubtle)
            TextField("Filter by team", text: $text)
                .textFieldStyle(.plain)
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: {
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
        .frame(maxWidth: .infinity)
    }
}

private struct LiveDot: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(Color.live)
            .frame(width: 6, height: 6)
            .scaleEffect(pulse ? 1.3 : 0.85)
            .opacity(pulse ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)
            .onAppear { pulse = true }
    }
}
