import SwiftUI
import PlayByPlayKit

struct PlaysSearchView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var pbp = store.playByPlayStore

        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Picker("League", selection: $pbp.selectedLeague) {
                        ForEach(pbp.leagues, id: \.key) { league in
                            Text(league.displayName).tag(league)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 300)
                    .onChange(of: pbp.selectedLeague) { _, _ in
                        pbp.games = []
                        Task { await pbp.loadLiveGames() }
                    }

                    TextField("Search teams…", text: $pbp.searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(Typography.body)

                    Button {
                        Task { await pbp.loadLiveGames() }
                    } label: {
                        if pbp.loadingGames {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh live games")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.bgRaised)

            Divider().background(Color.bbBorder)

            if pbp.selectedGame != nil {
                PlaysStreamView()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        if let err = pbp.gamesError {
                            Text(err)
                                .font(Typography.body)
                                .foregroundStyle(Color.live)
                                .padding()
                        }
                        if pbp.filteredGames.isEmpty && !pbp.loadingGames {
                            Text("No live games for \(pbp.selectedLeague.displayName).")
                                .font(Typography.body)
                                .foregroundStyle(Color.textSubtle)
                                .padding(.top, 40)
                        }
                        ForEach(pbp.filteredGames) { game in
                            GameRow(game: game)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    pbp.startStreaming(game)
                                }
                        }
                    }
                    .padding(20)
                }
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
}

private struct GameRow: View {
    let game: Game

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.shortName)
                    .font(Typography.playerName)
                    .foregroundStyle(Color.textPrimary)
                Text(game.statusDetail)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(game.awayTeam) \(game.awayScore) — \(game.homeScore) \(game.homeTeam)")
                    .font(Typography.statLabel)
                    .foregroundStyle(Color.textMuted)
                Text(game.period)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSubtle)
        }
        .padding(14)
        .background(Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
