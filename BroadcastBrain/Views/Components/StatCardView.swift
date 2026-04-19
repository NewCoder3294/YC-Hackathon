import SwiftUI

struct StatCardView: View {
    let card: StatCard

    var body: some View {
        if card.kind == .whisper {
            whisperBody
        } else {
            statBody
        }
    }

    private var statBody: some View {
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

    private var whisperBody: some View {
        let isAuto = card.rawTranscript.isEmpty
        return StackCard(kind: .precedent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: isAuto
                          ? "waveform.circle.fill"
                          : "bubble.left.and.text.bubble.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.esoteric)
                    Text(isAuto
                         ? "AGENT WHISPER · NEXT 30s"
                         : "WHISPER · \(card.player.uppercased())")
                        .font(Typography.sectionHead)
                        .foregroundStyle(Color.esoteric)
                    Spacer()
                    if isAuto {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textSubtle)
                            .help("Read aloud by the agent")
                    }
                    SportradarBadge()
                }
                if !isAuto {
                    Text("You asked: \"\(card.rawTranscript)\"")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                        .italic()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !card.player.isEmpty, card.player != "Agent" {
                    Text(card.player.uppercased())
                        .font(Typography.chip)
                        .tracking(0.5)
                        .foregroundStyle(Color.textMuted)
                }
                Text(card.answer ?? "—")
                    .font(Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
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
