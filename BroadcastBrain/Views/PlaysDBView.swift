import SwiftUI
import PlayByPlayKit

struct PlaysDBView: View {
    @Environment(AppStore.self) private var store

    @State private var entries: [SavedGameEntry] = []
    @State private var selected: SavedGameEntry?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.bbBorder)

            if let sel = selected {
                detailView(sel)
            } else {
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .onAppear { reload() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let sel = selected {
                Button {
                    selected = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("All saved games").font(Typography.body)
                    }
                    .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(sel.game.game.shortName)
                    .font(Typography.playerName)
                    .foregroundStyle(Color.textPrimary)
            } else {
                Text("PLAYS DB")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                Text("\(entries.count) games")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bgRaised)
    }

    private var listView: some View {
        ScrollView {
            VStack(spacing: 8) {
                if entries.isEmpty {
                    Text("No saved games yet. Start streaming one from the Plays tab.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textSubtle)
                        .padding(.top, 40)
                }
                ForEach(entries) { entry in
                    SavedGameRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = entry }
                }
            }
            .padding(20)
        }
    }

    private func detailView(_ entry: SavedGameEntry) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(entry.game.periods, id: \.number) { period in
                    Text(period.displayValue ?? "Period \(period.number)")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.textSubtle)
                        .padding(.top, 8)
                    ForEach(period.plays) { play in
                        PlayRow(play: play, compact: entry.game)
                    }
                }
            }
            .padding(16)
        }
    }

    private func reload() {
        entries = store.playByPlayStore.listSavedGames()
    }
}

private struct SavedGameRow: View {
    let entry: SavedGameEntry

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.leagueKey.uppercased())
                .font(Typography.chip)
                .foregroundStyle(Color.esoteric)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.bgSubtle)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.game.game.shortName)
                    .font(Typography.playerName)
                    .foregroundStyle(Color.textPrimary)
                Text(entry.game.game.statusDetail)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.game.totalPlays) plays")
                    .font(Typography.statLabel)
                    .foregroundStyle(Color.textMuted)
                Text(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))
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
