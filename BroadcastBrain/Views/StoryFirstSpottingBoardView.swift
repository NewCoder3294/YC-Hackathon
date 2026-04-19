import SwiftUI

struct StoryFirstSpottingBoardView: View {
    @Environment(AppStore.self) private var store
    @State private var leftFilter: String = ""
    @State private var rightFilter: String = ""
    @State private var pinnedIds: Set<String> = []
    @State private var expandedIds: Set<String> = []

    private var teams: (left: String, right: String) {
        let parts = store.currentSession.title.components(separatedBy: " vs ")
        let l = parts.first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Home"
        let r = parts.dropFirst().first?.components(separatedBy: " ·").first?.trimmingCharacters(in: .whitespaces) ?? "Away"
        return (l, r)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                Circle().fill(Color.esoteric).frame(width: 6, height: 6)
                Text("STORY-FIRST")
                    .font(Typography.chip)
                    .foregroundStyle(Color.esoteric)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.esoteric)
            }
            .padding(.leading, 20)

            Spacer()

            HStack(spacing: 0) {
                Button { store.spottingMode = nil } label: {
                    Text("MY STYLE")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.bgHover)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                Button {} label: {
                    Text("CASES")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                strandPicker
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.trailing, 20)
        }
        .frame(height: 44)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bbBorder).frame(height: 1) }
    }

    @State private var strandFilter: StoryStrand = .all

    private var strandPicker: some View {
        HStack(spacing: 0) {
            ForEach(StoryStrand.allCases, id: \.self) { s in
                Button { strandFilter = s } label: {
                    Text(s.label)
                        .font(Typography.chip)
                        .foregroundStyle(strandFilter == s ? Color.textPrimary : Color.textSubtle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(strandFilter == s ? Color.bgHover : Color.clear)
                }
                .buttonStyle(.plain)
                if s != StoryStrand.allCases.last {
                    Rectangle().fill(Color.bbBorder).frame(width: 1, height: 14)
                }
            }
        }
    }

    // MARK: Team column

    private func teamColumn(teamName: String, accentHex: String, filter: Binding<String>) -> some View {
        let accent = Color(hex: accentHex)
        let all = (store.matchCache?.players ?? []).filter { $0.team == teamName }
        let query = filter.wrappedValue.lowercased()
        var filtered = query.isEmpty ? all : all.filter {
            $0.name.lowercased().contains(query) || $0.position.lowercased().contains(query)
        }
        if strandFilter != .all {
            filtered = filtered.filter { strandFilter.matches($0) }
        }
        let pinned   = filtered.filter { pinnedIds.contains($0.name) }
        let unpinned = filtered.filter { !pinnedIds.contains($0.name) }

        return VStack(alignment: .leading, spacing: 0) {
            columnHeader(teamName: teamName, accent: accent, playerCount: all.count)
            filterBar(placeholder: "FILTER \(teamName.uppercased()) PLAYERS...", text: filter)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(pinned + unpinned, id: \.name) { player in
                        StoryPlayerCard(
                            player: player,
                            isPinned: pinnedIds.contains(player.name),
                            isExpanded: expandedIds.contains(player.name),
                            onTogglePin: {
                                if pinnedIds.contains(player.name) { pinnedIds.remove(player.name) }
                                else { pinnedIds.insert(player.name) }
                            },
                            onToggleExpand: {
                                if expandedIds.contains(player.name) { expandedIds.remove(player.name) }
                                else { expandedIds.insert(player.name) }
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
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
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

// MARK: - Story strand filter

enum StoryStrand: CaseIterable {
    case all, arcs, milestones, rivalries

    var label: String {
        switch self {
        case .all:        return "ALL"
        case .arcs:       return "ARCS"
        case .milestones: return "MILESTONES"
        case .rivalries:  return "RIVALRIES"
        }
    }

    func matches(_ player: Player) -> Bool {
        switch self {
        case .all: return true
        case .arcs:
            return player.keyStats["storyHero"] != nil
        case .milestones:
            let hero = (player.keyStats["storyHero"] ?? "").lowercased()
            return hero.contains("first") || hero.contains("record") || hero.contains("final") || hero.contains("hat-trick")
        case .rivalries:
            return (player.keyStats["stat4"] ?? "").contains("vs") || (player.keyStats["storyHero"] ?? "").lowercased().contains("vs")
        }
    }
}

// MARK: - Story Player Card

private struct StoryPlayerCard: View {
    let player: Player
    let isPinned: Bool
    let isExpanded: Bool
    let onTogglePin: () -> Void
    let onToggleExpand: () -> Void

    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider().background(Color.bbBorder).padding(.horizontal, 12)
            storyBody
            if isExpanded { expandedStats }
            cardFooter
        }
        .background(hovered ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isPinned ? Color.esoteric.opacity(0.6) : Color.bbBorder,
                        lineWidth: isPinned ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .onHover { hovered = $0 }
    }

    // Jersey + name + pin + expand
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
                        .background(Color.esoteric, in: RoundedRectangle(cornerRadius: 2))
                    }

                    Spacer()

                    Button(action: onTogglePin) {
                        Image(systemName: isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(isPinned ? Color.esoteric : Color.textSubtle)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Text(player.position)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.textSubtle)
                    if hasStory {
                        Text("·")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.textSubtle)
                        Text("HAS ARC")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.esoteric)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 8)
    }

    // The main story beat
    private var storyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Headline arc
            Text(headline)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(hasStory ? Color.textPrimary : Color.textMuted)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            // Context lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(contextLines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Rectangle()
                            .fill(Color.esoteric.opacity(0.6))
                            .frame(width: 2, height: 10)
                            .padding(.top, 3)
                        Text(line)
                            .font(Typography.chip)
                            .foregroundStyle(Color.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Expand / collapse toggle
            if hasExpandableStats {
                Button(action: onToggleExpand) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "HIDE STATS" : "SHOW STATS")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.textSubtle)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.textSubtle)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // Inline stats revealed on expand
    private var expandedStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().background(Color.bbBorder).padding(.horizontal, 12)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(allStatLines, id: \.self) { line in
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.verified)
                        Text(line)
                            .font(Typography.chip)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private var cardFooter: some View {
        HStack {
            SportradarBadge()
            Spacer()
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    // MARK: Helpers

    private var hasStory: Bool { player.keyStats["storyHero"] != nil }

    private var headline: String {
        if let hero = player.keyStats["storyHero"] { return hero }
        if let s1 = player.keyStats["stat1"] { return s1 }
        return "No narrative arc seeded."
    }

    private var contextLines: [String] {
        var lines: [String] = []
        if player.keyStats["storyHero"] != nil {
            if let s1 = player.keyStats["stat1"] { lines.append(s1) }
            if let s2 = player.keyStats["stat2"] { lines.append(s2) }
        } else {
            if let s2 = player.keyStats["stat2"] { lines.append(s2) }
            if let s3 = player.keyStats["stat3"] { lines.append(s3) }
        }
        return lines
    }

    private var hasExpandableStats: Bool {
        player.keyStats["stat1"] != nil || player.keyStats["stat2"] != nil
    }

    private var allStatLines: [String] {
        ["stat1", "stat2", "stat3", "stat4"].compactMap { player.keyStats[$0] }
    }
}
