import SwiftUI

enum BoardDensity: String, CaseIterable { case compact = "COMPACT", standard = "STANDARD", full = "FULL" }

struct StatsFirstSpottingBoardView: View {
    @Environment(AppStore.self) private var store
    @State private var density: BoardDensity = .standard
    @State private var leftFilter: String = ""
    @State private var rightFilter: String = ""
    @State private var pinnedIds: Set<String> = []

    private var teams: (left: String, right: String) {
        let parts = store.currentSession.title.components(separatedBy: " vs ")
        let l = parts.first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Home"
        let r = parts.dropFirst().first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Away"
        return (l, r)
    }

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
                    teamColumn(
                        teamName: teams.left,
                        accentHex: "#7AB8E3",
                        filter: $leftFilter
                    )
                    Rectangle().fill(Color.bbBorder).frame(width: 1)
                    teamColumn(
                        teamName: teams.right,
                        accentHex: "#D06060",
                        filter: $rightFilter
                    )
                }
            }
        }
        .background(Color.bgBase)
    }

    // MARK: - Sub-header

    private var subHeader: some View {
        HStack(spacing: 0) {
            // Left cluster
            HStack(spacing: 10) {
                Text("SPOTTING BOARD")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                Circle().fill(Color.verified).frame(width: 6, height: 6)
                Text("STATS-FIRST")
                    .font(Typography.chip)
                    .foregroundStyle(Color.verified)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.verified)
            }
            .padding(.leading, 20)

            Spacer()

            // Right cluster
            HStack(spacing: 0) {
                styleButton
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                casesButton
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

    private var styleButton: some View {
        Button {
            store.spottingMode = nil
        } label: {
            Text("MY STYLE")
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.bgHover)
        }
        .buttonStyle(.plain)
    }

    private var casesButton: some View {
        Button {} label: {
            Text("CASES")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var densityPicker: some View {
        HStack(spacing: 0) {
            ForEach(BoardDensity.allCases, id: \.self) { d in
                Button { density = d } label: {
                    Text(d.rawValue)
                        .font(Typography.chip)
                        .foregroundStyle(density == d ? Color.textPrimary : Color.textSubtle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(density == d ? Color.bgHover : Color.clear)
                }
                .buttonStyle(.plain)
                if d != BoardDensity.allCases.last {
                    Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                }
            }
        }
    }

    // MARK: - Team column

    private func teamColumn(teamName: String, accentHex: String, filter: Binding<String>) -> some View {
        let accent = Color(hex: accentHex)
        let allPlayers = (store.matchCache?.players ?? []).filter { $0.team == teamName }
        let query = filter.wrappedValue.lowercased()
        let players = query.isEmpty ? allPlayers : allPlayers.filter {
            $0.name.lowercased().contains(query) || $0.position.lowercased().contains(query)
        }
        let pinned = players.filter { pinnedIds.contains($0.name) }
        let unpinned = players.filter { !pinnedIds.contains($0.name) }

        return VStack(alignment: .leading, spacing: 0) {
            // Column header
            columnHeader(teamName: teamName, accent: accent, playerCount: allPlayers.count)

            // Filter bar
            filterBar(placeholder: "FILTER \(teamName.uppercased()) PLAYERS...", text: filter)

            // Player list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(pinned + unpinned, id: \.name) { player in
                        StatsPlayerCard(
                            player: player,
                            density: density,
                            isPinned: pinnedIds.contains(player.name),
                            onTogglePin: {
                                if pinnedIds.contains(player.name) {
                                    pinnedIds.remove(player.name)
                                } else {
                                    pinnedIds.insert(player.name)
                                }
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

    private func columnHeader(teamName: String, accent: Color, playerCount: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(accent).frame(width: 8, height: 8)
            Text(teamName.uppercased())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
            Text(String(teamName.prefix(3)).uppercased())
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))

            Spacer()
            Text("\(playerCount) PLAYERS")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
            SportradarBadge()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    private func filterBar(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSubtle)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Typography.chip)
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }
}

// MARK: - Player Card

private struct StatsPlayerCard: View {
    let player: Player
    let density: BoardDensity
    let isPinned: Bool
    let onTogglePin: () -> Void

    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            if density != .compact {
                Divider().background(Color.bbBorder).padding(.horizontal, 12)
                statsGrid.padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
            }
            if density == .full {
                Divider().background(Color.bbBorder).padding(.horizontal, 12)
                fullExtra.padding(.horizontal, 12).padding(.vertical, 8)
            }
            HStack {
                SportradarBadge()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(hovered ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isPinned ? Color.verified.opacity(0.5) : Color.bbBorder, lineWidth: isPinned ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { hovered = $0 }
    }

    // Jersey + name + pin + edit
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if isPinned {
                        HStack(spacing: 3) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("PINNED")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(Color.bgBase)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.verified, in: RoundedRectangle(cornerRadius: 2))
                    }

                    Spacer()

                    Button(action: onTogglePin) {
                        Image(systemName: isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(isPinned ? Color.verified : Color.textSubtle)
                    }
                    .buttonStyle(.plain)
                }

                // Position tags
                let tags = positionTags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.textSubtle)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, density == .compact ? 8 : 6)
    }

    // Three big stat columns
    private var statsGrid: some View {
        let slots = statSlots
        return HStack(alignment: .top, spacing: 0) {
            ForEach(slots.indices, id: \.self) { i in
                let slot = slots[i]
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.value)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(slot.label)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.textSubtle)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if i < slots.count - 1 {
                    Rectangle().fill(Color.bbBorder).frame(width: 1, height: 36)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    // Tactical note shown in full density
    private var fullExtra: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundStyle(Color.esoteric)
                .padding(.top, 1)
            Text(player.keyStats["tactical"] ?? "—")
                .font(Typography.chip)
                .foregroundStyle(Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Parse "5.2 xG · Top-3 this WC" → ("5.2", "xG")
    private var statSlots: [(value: String, label: String)] {
        let keys = ["stat1", "stat2", "stat3"]
        return keys.compactMap { key -> (String, String)? in
            guard let raw = player.keyStats[key], !raw.isEmpty else { return nil }
            let clean = raw.components(separatedBy: " · ").first ?? raw
            let parts = clean.components(separatedBy: " ")
            let val = parts.first ?? "—"
            let lbl = parts.dropFirst().joined(separator: " ")
            return (val.isEmpty ? "—" : val, lbl.isEmpty ? key : lbl)
        }
    }

    private var positionTags: [String] {
        var tags = [player.position]
        if let s1 = player.keyStats["stat1"] {
            // Pull highlighted segment after ·
            let parts = s1.components(separatedBy: " · ")
            if parts.count > 1 { tags.append(parts[1]) }
        }
        return tags.filter { !$0.isEmpty }
    }
}
