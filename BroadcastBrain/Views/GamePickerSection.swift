import SwiftUI
import PlayByPlayKit

/// League + live-game picker embedded inside `NewMatchSheet`. Optional — if the
/// commentator skips it, the session still works but the WhisperEngine runs
/// with an empty plays window.
struct GamePickerSection: View {
    @Environment(AppStore.self) private var store

    @Binding var selectedLeague: League?
    @Binding var selectedGame: Game?
    @Binding var homeTeam: String
    @Binding var awayTeam: String
    @Binding var tournament: String
    @Binding var venue: String

    @State private var loading: Bool = false
    @State private var games: [Game] = []
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("LIVE FEED (OPTIONAL)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
                    .tracking(1.4)
                Spacer()
                if selectedGame != nil {
                    Button(action: clearSelection) {
                        Text("CLEAR")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(Color.textSubtle)
                    }
                    .buttonStyle(.plain)
                    .help("Clear live-game selection")
                }
            }

            HStack(spacing: 10) {
                leaguePicker
                Button(action: fetch) {
                    HStack(spacing: 6) {
                        if loading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise").font(.system(size: 10))
                        }
                        Text("FETCH GAMES")
                            .font(Typography.chip)
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(Color.textPrimary)
                    .background(selectedLeague == nil ? Color.bgHover : Color.bgSubtle,
                                in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.bbBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedLeague == nil || loading)
                Spacer()
            }

            if let error {
                Text(error)
                    .font(Typography.chip)
                    .foregroundStyle(Color.live)
                    .lineLimit(2)
            }

            if let selectedGame {
                selectedRow(selectedGame)
            } else if !games.isEmpty {
                gamesList
            }
        }
    }

    private var leaguePicker: some View {
        Menu {
            ForEach(League.all, id: \.key) { league in
                Button(league.displayName) {
                    selectedLeague = league
                    games = []
                    error = nil
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedLeague?.displayName.uppercased() ?? "CHOOSE LEAGUE")
                    .font(Typography.chip)
                    .tracking(0.5)
                    .foregroundStyle(selectedLeague == nil ? Color.textMuted : Color.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 8))
                    .foregroundStyle(Color.textSubtle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(selectedLeague == nil ? Color.bbBorder : Color.live.opacity(0.6),
                            lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var gamesList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(games, id: \.id) { game in
                    Button(action: { select(game) }) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.shortName.uppercased())
                                    .font(Typography.chip)
                                    .tracking(0.4)
                                    .foregroundStyle(Color.textPrimary)
                                Text(game.statusDetail)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.textSubtle)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(game.awayScore) – \(game.homeScore)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.bbBorder.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 160)
    }

    private func selectedRow(_ game: Game) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.live)
            VStack(alignment: .leading, spacing: 2) {
                Text(game.shortName.uppercased())
                    .font(Typography.chip)
                    .tracking(0.4)
                    .foregroundStyle(Color.textPrimary)
                Text("\(selectedLeague?.displayName ?? "") · \(game.statusDetail)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.live.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.live.opacity(0.6), lineWidth: 1)
        )
    }

    private func fetch() {
        guard let league = selectedLeague, !loading else { return }
        loading = true
        error = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                let fetched = try await PlayByPlay.getLiveGames(league)
                self.games = fetched
                if fetched.isEmpty {
                    self.error = "No games returned for \(league.displayName)."
                }
            } catch {
                self.games = []
                self.error = "Failed to load games: \(error.localizedDescription)"
            }
        }
    }

    private func select(_ game: Game) {
        selectedGame = game
        // Auto-fill the simple form fields so the Match title reads well.
        homeTeam = game.homeTeam
        awayTeam = game.awayTeam
        if tournament.isEmpty, let league = selectedLeague {
            tournament = league.displayName
        }
        if venue.isEmpty {
            venue = game.statusDetail
        }
    }

    private func clearSelection() {
        selectedGame = nil
    }
}
