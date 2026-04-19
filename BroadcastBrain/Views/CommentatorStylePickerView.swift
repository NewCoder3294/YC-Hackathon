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
                Text("READY · PRE-INDEXED OVERNIGHT")
                    .font(Typography.chip)
                    .foregroundStyle(Color.verified)
            }
            .padding(.bottom, 14)

            Text("Pick your commentator style.")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, 8)

            Text("\(playerCount) players · \(storylineCount) storylines pre-indexed.")
                .font(Typography.chip)
                .foregroundStyle(Color.textMuted)
                .padding(.bottom, 24)

            // Style rows
            VStack(spacing: 1) {
                StyleRow(
                    mode: .stats,
                    title: "STATS-FIRST",
                    badge: nil,
                    description: "xG · xA · progressive carries. Numbers lead.",
                    detail: "\(playerCount) player stats · \(storylineCount) matchups cached.",
                    hovered: $hovered
                )
                StyleRow(
                    mode: .story,
                    title: "STORY-FIRST",
                    badge: "RECOMMENDED FOR YOU",
                    description: "Arcs, feuds, milestones. Narrative leads.",
                    detail: "World Cup · tournament history · season arcs.",
                    hovered: $hovered
                )
                StyleRow(
                    mode: .tactical,
                    title: "TACTICAL",
                    badge: nil,
                    description: "Formations, pressing, roles. Function leads.",
                    detail: "Top scoreboard list · goals · comments.",
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

    var body: some View {
        Button {
            store.spottingMode = mode
            store.selectedSurface = .research
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Stat preview block
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mode == .stats ? "5.2" : mode == .story ? "W/L" : "4-3")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                    Text(mode == .stats ? "xG" : mode == .story ? "Cup Final" : "Formation")
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
