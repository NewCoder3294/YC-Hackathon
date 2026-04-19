import SwiftUI

/// Ported visual from reference/frontend/design-handoff/feature-1/f1-components.jsx
/// PlayerCell — mode-aware body. Stats / Story / Tactical.
struct PlayerCellView: View {
    let player: Player
    let mode: SpottingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            body(for: mode)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("#\(player.jersey)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .frame(minWidth: 26, alignment: .leading)
            Text(player.position)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.textSubtle)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 2))
            Text(player.name.uppercased())
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func body(for mode: SpottingMode) -> some View {
        switch mode {
        case .stats: statsBody
        case .story: storyBody
        case .tactical: tacticalBody
        }
    }

    private var statsBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(statLines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(Color.verified)
                        .frame(width: 2, height: 10)
                        .offset(y: 3)
                    Text(line)
                        .font(Typography.statLabel)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var storyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let hero = player.keyStats["storyHero"] {
                Text(hero)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textPrimary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No story beat seeded for this player.")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            ForEach(statLines.prefix(2), id: \.self) { line in
                Text("— \(line)")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tacticalBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tac = player.keyStats["tactical"] {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(Color.esoteric)
                        .font(.system(size: 11))
                    Text(tac)
                        .font(Typography.statLabel)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("No tactical note seeded.")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
            if let s1 = player.keyStats["stat1"] {
                Text("· \(s1)")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
        }
    }

    /// Pull stat1..stat4 in order, skip nil.
    private var statLines: [String] {
        ["stat1", "stat2", "stat3", "stat4"].compactMap { player.keyStats[$0] }
    }
}
