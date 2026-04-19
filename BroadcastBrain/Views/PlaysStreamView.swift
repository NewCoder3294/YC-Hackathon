import SwiftUI
import PlayByPlayKit

struct PlaysStreamView: View {
    @Environment(AppStore.self) private var store

    private var pbp: PlayByPlayStore { store.playByPlayStore }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.bbBorder)

            if let err = pbp.streamError {
                Text(err)
                    .font(Typography.body)
                    .foregroundStyle(Color.live)
                    .padding(12)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(pbp.plays.reversed()) { play in
                        PlayRow(play: play, compact: pbp.currentCompact)
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { pbp.clearSelection() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("ALL GAMES")
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
            .help("Back to game list")

            VStack(alignment: .leading, spacing: 2) {
                Text(pbp.selectedGame?.shortName ?? "")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                Text(streamStatus)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            Spacer()
            if let game = pbp.currentCompact?.game {
                Text("\(game.awayTeam) \(game.awayScore) — \(game.homeScore) \(game.homeTeam)")
                    .font(Typography.statLabel)
                    .foregroundStyle(Color.textMuted)
            }
            Button {
                pbp.clearSelection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                    Text("STOP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.live)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.live.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.live.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Stop streaming")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
    }

    private var streamStatus: String {
        if pbp.streamError != nil { return "stopped · error" }
        if pbp.isStreaming { return "streaming · polling every 500ms · \(pbp.plays.count) plays" }
        return "\(pbp.plays.count) plays"
    }
}

struct PlayRow: View {
    let play: CompactPlay
    let compact: CompactGame?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(periodLabel)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                Text(play.clock ?? "")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let teamName = teamName {
                    Text(teamName)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                }
            }
            Spacer()
            if play.scoringPlay == true {
                Text("SCORE")
                    .font(Typography.chip)
                    .foregroundStyle(Color.verified)
            }
        }
        .padding(10)
        .background(Color.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var periodLabel: String {
        play.period?.displayValue ?? play.period.map { "P\($0.number)" } ?? ""
    }

    private var headline: String {
        play.text ?? play.type ?? "—"
    }

    private var teamName: String? {
        guard let id = play.teamId, let team = compact?.teams[id] else { return nil }
        return team.name ?? team.abbreviation
    }
}
