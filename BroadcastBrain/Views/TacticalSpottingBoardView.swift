import SwiftUI

struct TacticalSpottingBoardView: View {
    @Environment(AppStore.self) private var store
    @State private var leftFilter:  String = ""
    @State private var rightFilter: String = ""
    @State private var pinnedIds:   Set<String> = []
    @State private var density: BoardDensity = .standard

    private var teams: (left: String, right: String) {
        let parts = store.currentSession.title.components(separatedBy: " vs ")
        let l = parts.first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Home"
        let r = parts.dropFirst().first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Away"
        return (l, r)
    }

    // Known formations for the 2022 WC Final; derived from title as fallback
    private let formations: [String: (code: String, shape: String)] = [
        "Argentina": ("ARG", "4-4-2"),
        "France":    ("FRA", "4-2-3-1"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: store.currentSession.title,
                isAirplane: true,
                latencyMs: store.lastLatencyMs
            )
            subHeader
            ZStack {
                DottedGrid()
                HStack(alignment: .top, spacing: 0) {
                    teamColumn(teamName: teams.left,  accentHex: "#7AB8E3", filter: $leftFilter)
                    Rectangle().fill(Color.bbBorder).frame(width: 1)
                    teamColumn(teamName: teams.right, accentHex: "#D06060", filter: $rightFilter)
                }
            }
        }
        .background(Color.bgBase)
    }

    // MARK: Sub-header

    private var subHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("SPOTTING BOARD")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                Circle().fill(Color.tactical).frame(width: 6, height: 6)
                Text("TACTICAL")
                    .font(Typography.chip)
                    .foregroundStyle(Color.tactical)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.tactical)
            }
            .padding(.leading, 20)

            Spacer()

            HStack(spacing: 0) {
                Button { store.spottingMode = nil } label: {
                    Text("MY STYLE")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.bgHover)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                Button {} label: {
                    Text("CASES")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                densityPicker
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.trailing, 20)
        }
        .frame(height: 44)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    private var densityPicker: some View {
        HStack(spacing: 0) {
            ForEach(BoardDensity.allCases, id: \.self) { d in
                Button { density = d } label: {
                    Text(d.rawValue)
                        .font(Typography.chip)
                        .foregroundStyle(density == d ? Color.textPrimary : Color.textSubtle)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(density == d ? Color.bgHover : Color.clear)
                }
                .buttonStyle(.plain)
                if d != BoardDensity.allCases.last {
                    Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                }
            }
        }
    }

    // MARK: Team column

    private func teamColumn(teamName: String, accentHex: String, filter: Binding<String>) -> some View {
        let accent   = Color(hex: accentHex)
        let all      = (store.matchCache?.players ?? []).filter { $0.team == teamName }
        let query    = filter.wrappedValue.lowercased()
        let players  = query.isEmpty ? all : all.filter {
            $0.name.lowercased().contains(query) || $0.position.lowercased().contains(query)
        }
        let pinned   = players.filter { pinnedIds.contains($0.name) }
        let unpinned = players.filter { !pinnedIds.contains($0.name) }
        let meta     = formations[teamName]

        return VStack(alignment: .leading, spacing: 0) {
            columnHeader(teamName: teamName, accent: accent, meta: meta, playerCount: all.count)
            filterBar(placeholder: "FILTER \(teamName.uppercased()) PLAYERS...", text: filter)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(pinned + unpinned, id: \.name) { player in
                        TacticalPlayerCard(
                            player: player,
                            density: density,
                            isPinned: pinnedIds.contains(player.name),
                            onTogglePin: {
                                if pinnedIds.contains(player.name) { pinnedIds.remove(player.name) }
                                else { pinnedIds.insert(player.name) }
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgBase)
    }

    private func columnHeader(teamName: String, accent: Color, meta: (code: String, shape: String)?, playerCount: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(accent).frame(width: 8, height: 8)
            Text(teamName.uppercased())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
            if let meta {
                Text(meta.code)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                Text(meta.shape)
                    .font(Typography.chip)
                    .foregroundStyle(Color.tactical)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.tactical.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
            Text("\(playerCount) PLAYERS")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
            SportradarBadge()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    private func filterBar(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11)).foregroundStyle(Color.textSubtle)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Typography.chip).foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }
}

// MARK: - Press zone

private enum PressZone: String {
    case high = "HIGH", mid = "MID", passive = "PASSIVE"

    var color: Color {
        switch self {
        case .high:    return Color.verified
        case .mid:     return Color.esoteric
        case .passive: return Color.textSubtle
        }
    }

    static func from(position: String, tactical: String?) -> PressZone {
        let tac = (tactical ?? "").lowercased()
        if tac.contains("press") || tac.contains("high line") { return .high }
        if tac.contains("screens") || tac.contains("deep") || tac.contains("drops") { return .passive }
        switch position {
        case "FW": return .high
        case "MF": return .mid
        default:   return .passive
        }
    }
}

// MARK: - Tactical Player Card

private struct TacticalPlayerCard: View {
    let player: Player
    let density: BoardDensity
    let isPinned: Bool
    let onTogglePin: () -> Void

    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider().background(Color.bbBorder).padding(.horizontal, 12)
            tacticalNote
            if density != .compact { bottomStats }
            if density == .full    { statLines }
            footerRow
        }
        .background(hovered ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isPinned ? Color.tactical.opacity(0.6) : Color.bbBorder,
                        lineWidth: isPinned ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { hovered = $0 }
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(player.jersey)
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .frame(width: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.name.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)

                    if isPinned {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill").font(.system(size: 8))
                            Text("PINNED").font(.system(size: 9, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(Color.bgBase)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.tactical, in: RoundedRectangle(cornerRadius: 2))
                    }

                    Spacer()

                    Button(action: onTogglePin) {
                        Image(systemName: isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(isPinned ? Color.tactical : Color.textSubtle)
                    }
                    .buttonStyle(.plain)
                }

                // Position + press zone inline
                HStack(spacing: 6) {
                    Text(player.position)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textSubtle)
                    let zone = PressZone.from(position: player.position, tactical: player.keyStats["tactical"])
                    Text("·")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.textSubtle)
                    Text("PRESS \(zone.rawValue)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(zone.color)
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
    }

    private var tacticalNote: some View {
        Text(player.keyStats["tactical"] ?? "No tactical note.")
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.textMuted)
            .italic()
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
            .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // KEY ACTIONS | KEY PASSES | PRESS ZONE
    private var bottomStats: some View {
        let zone = PressZone.from(position: player.position, tactical: player.keyStats["tactical"])
        let actions = extractNumber(from: player.keyStats["stat1"])
        let passes  = extractNumber(from: player.keyStats["stat2"])

        return HStack(spacing: 0) {
            tacticalStatCell(value: actions ?? "—", label: "KEY ACTIONS")
            Rectangle().fill(Color.bbBorder).frame(width: 1, height: 30)
            tacticalStatCell(value: passes ?? "—", label: "KEY PASSES")
            Rectangle().fill(Color.bbBorder).frame(width: 1, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(zone.color)
                Text("PRESS ZONE")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color.bgSubtle)
        .overlay(alignment: .top) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    // Full stat lines in expanded density
    private var statLines: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(["stat1","stat2","stat3","stat4"].compactMap({ player.keyStats[$0] }), id: \.self) { line in
                HStack(spacing: 6) {
                    Rectangle().fill(Color.tactical).frame(width: 2, height: 10).padding(.top, 2)
                    Text(line)
                        .font(Typography.chip).foregroundStyle(Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    private var footerRow: some View {
        HStack { SportradarBadge(); Spacer() }
            .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func tacticalStatCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    // Extract leading number from strings like "5.2 xG · Top-3" → "5.2", "86% tackle" → "86%"
    private func extractNumber(from raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let first = raw.components(separatedBy: " ").first ?? ""
        return first.isEmpty ? nil : first
    }
}
