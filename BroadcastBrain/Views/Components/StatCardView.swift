import SwiftUI

struct StatCardView: View {
    let card: StatCard

    var body: some View {
        StackCard(kind: .stat) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(card.player.uppercased())
                        .font(Typography.playerName)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    SportradarBadge()
                }
                Text(card.statValue)
                    .font(Typography.heroStat)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(card.contextLine)
                    .font(Typography.statLabel)
                    .foregroundStyle(Color.textMuted)
                HStack {
                    Text("from: \"\(card.rawTranscript)\"")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                        .lineLimit(1)
                    Spacer()
                    LatencyTag(ms: card.latencyMs)
                }
            }
        }
    }
}

struct NoDataCardView: View {
    let rawTranscript: String

    var body: some View {
        StackCard(kind: .counter) {
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(Color.live)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("No verified data on that")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                    Text("from: \"\(rawTranscript)\"")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                        .lineLimit(1)
                }
            }
        }
    }
}
