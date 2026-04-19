import SwiftUI

struct CommentatorStylePickerView: View {
    @Environment(AppStore.self) private var store
    @State private var hovered: SpottingMode? = nil

    private var cache: MatchCache? { store.matchCache }

    private var playerCount: Int   { cache?.players.count ?? 0 }
    private var storylineCount: Int { cache?.storylines.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header pill
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.verified)
                Text("MATCH CACHE READY")
                    .font(Typography.chip)
                    .foregroundStyle(Color.verified)
            }
            .padding(.bottom, 14)

            Text("Pick your commentator style.")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 8)

            Text("\(playerCount) players · \(storylineCount) storylines cached for this match.")
                .font(Typography.chip)
                .foregroundStyle(Color.textMuted)
                .padding(.bottom, 24)

            // Style rows
            VStack(spacing: 1) {
                StyleRow(
                    mode: .stats,
                    title: "STATS-FIRST",
                    badge: nil,
                    description: "Numbers lead. Top 3 stats per player, ranked by impact.",
                    detail: "Best for data-driven calls and quick comparisons.",
                    hovered: $hovered
                )
                StyleRow(
                    mode: .story,
                    title: "STORY-FIRST",
                    badge: "RECOMMENDED",
                    description: "Narrative leads. Latest headline or storyline on each card.",
                    detail: "Best for colour commentary and player arcs.",
                    hovered: $hovered
                )
                StyleRow(
                    mode: .tactical,
                    title: "TACTICAL",
                    badge: nil,
                    description: "Matchups lead. Who each player faces and why it matters.",
                    detail: "Best for analytical breakdowns and individual battles.",
                    hovered: $hovered
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))

            // Footer
            HStack(spacing: 4) {
                Text("MODE IS A PREFERENCE — NOT A CAGE.")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                Button("SKIP — CUSTOMIZE FROM SCRATCH") {
                    store.spottingMode = .stats
                    store.selectedSurface = .research
                }
                .buttonStyle(.plain)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .underline()
            }
            .padding(.top, 16)
        }
        .padding(28)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
        .frame(maxWidth: 540)
    }
}

private struct StyleRow: View {
    @Environment(AppStore.self) private var store
    let mode: SpottingMode
    let title: String
    let badge: String?
    let description: String
    let detail: String
    @Binding var hovered: SpottingMode?

    var isHovered: Bool { hovered == mode }

    private var iconName: String {
        switch mode {
        case .stats:    return "chart.bar.fill"
        case .story:    return "book.fill"
        case .tactical: return "point.3.connected.trianglepath.dotted"
        }
    }

    private var label: String {
        switch mode {
        case .stats:    return "DATA"
        case .story:    return "ARC"
        case .tactical: return "MATCH"
        }
    }

    var body: some View {
        Button {
            store.spottingMode = mode
            store.selectedSurface = .research
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Mode icon
                VStack(spacing: 2) {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.textPrimary)
                    Text(label)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(Typography.sectionHead)
                            .foregroundStyle(Color.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.bgBase)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.esoteric, in: RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    Text(description)
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                    Text(detail)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? Color.textPrimary : Color.textSubtle)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(isHovered ? Color.bgHover : Color.bgRaised)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in hovered = isHovered ? mode : nil }
    }
}
