import AppKit
import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var theme
    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader(collapsed: theme.sidebarCollapsed)

            ScrollView {
                VStack(spacing: theme.sidebarCollapsed ? 10 : 18) {
                    if !theme.sidebarCollapsed {
                        MatchContextCard(
                            title: store.currentSession.title,
                            isLive: store.liveState == .listening
                        )
                        .padding(.horizontal, 12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if !theme.sidebarCollapsed {
                            SectionLabel(text: "WORKSPACE")
                                .padding(.horizontal, 16)
                        }

                        VStack(spacing: 2) {
                            surfaceRow(title: "Live",     systemImage: "dot.radiowaves.left.and.right", surface: .live)
                            surfaceRow(title: "Squads",   systemImage: "person.2.fill",                 surface: .squads)
                            surfaceRow(title: "Research", systemImage: "book.fill",                     surface: .research)
                            surfaceRow(title: "News",     systemImage: "newspaper.fill",                surface: .news)
                            surfaceRow(title: "Archive",  systemImage: "archivebox.fill",               surface: .archive)
                            surfaceRow(title: "Plays",    systemImage: "sportscourt.fill",              surface: .plays)
                            surfaceRow(title: "Plays DB", systemImage: "tray.full.fill",                surface: .playsDB)
                        }
                        .padding(.horizontal, theme.sidebarCollapsed ? 8 : 8)
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            NewSessionButton(collapsed: theme.sidebarCollapsed) { store.newSession() }
                .padding(.horizontal, theme.sidebarCollapsed ? 10 : 12)
                .padding(.top, 10)

            SidebarFooterControls(collapsed: theme.sidebarCollapsed)
                .padding(.horizontal, theme.sidebarCollapsed ? 10 : 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(Color.bgBase)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.sidebarEdge)
                .frame(width: 1)
        }
    }

    private func surfaceRow(title: String, systemImage: String, surface: Surface) -> some View {
        let selected: Bool = {
            if surface == .archive {
                return store.selectedSurface == .archive
            }
            return store.selectedArchiveId == nil && store.selectedSurface == surface
        }()

        let accessory: SidebarRowAccessory? = {
            if surface == .live && store.liveState == .listening { return .livePill }
            if surface == .archive && !store.sessionStore.sessions.isEmpty {
                return .count(store.sessionStore.sessions.count)
            }
            return nil
        }()

        return SidebarRow(
            title: title,
            systemImage: systemImage,
            selected: selected,
            accessory: accessory,
            collapsed: theme.sidebarCollapsed,
            glassNamespace: glassNamespace
        ) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                store.selectedArchiveId = nil
                store.selectedSurface = surface
            }
        }
    }
}

// MARK: - Brand header

private struct BrandHeader: View {
    let collapsed: Bool
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Group {
            if collapsed {
                VStack(spacing: 10) {
                    LogoMark()
                        .frame(width: 30, height: 30)
                    CollapseChevron(collapsed: true) { theme.toggleSidebar() }
                }
            } else {
                HStack(spacing: 10) {
                    LogoMark()
                        .frame(width: 30, height: 30)
                    Text("KLEOS")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    CollapseChevron(collapsed: false) { theme.toggleSidebar() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
        .padding(.horizontal, collapsed ? 0 : 16)
        .padding(.top, 34)
        .padding(.bottom, 8)
        .frame(height: 72, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderSoft).frame(height: 1)
        }
    }
}

private struct CollapseChevron: View {
    let collapsed: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: collapsed ? "chevron.right" : "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Color.textPrimary : Color.textSubtle)
                .frame(width: 24, height: 24)
                .background(hovering ? Color.bgSubtle : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? "Expand sidebar" : "Collapse sidebar")
    }
}

private struct LogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            let scale = s / 64
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color.bgRaised)
                RoundedRectangle(cornerRadius: 7).stroke(Color.bbBorder, lineWidth: 1)
                Canvas { ctx, _ in
                    let bars: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, red: Bool)] = [
                        (0, 0, 3, 32, false),
                        (7, 4, 3, 10, false),
                        (14, 2, 3, 14, false),
                        (21, 6, 3, 6, true),
                        (28, 3, 3, 12, false),
                        (7, 18, 3, 10, false),
                        (14, 16, 3, 14, false),
                        (21, 20, 3, 6, false),
                        (28, 17, 3, 12, false),
                    ]
                    for b in bars {
                        let rect = CGRect(
                            x: (16 + b.x) * scale,
                            y: (16 + b.y) * scale,
                            width: b.w * scale,
                            height: b.h * scale
                        )
                        ctx.fill(
                            Path(rect),
                            with: .color(b.red ? Color.live : Color.textPrimary)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Match context card

private struct MatchContextCard: View {
    let title: String
    let isLive: Bool

    private var parts: (home: String, away: String, subtitle: String) {
        let pieces = title.components(separatedBy: " · ")
        let matchup = pieces.first ?? title
        let sub = pieces.dropFirst().joined(separator: " · ")
        let teams = matchup.components(separatedBy: " vs ")
        let home = teams.first.map(abbrev) ?? "—"
        let away = teams.dropFirst().first.map(abbrev) ?? "—"
        return (home, away, sub.isEmpty ? "TODAY" : sub.uppercased())
    }

    private func abbrev(_ country: String) -> String {
        let cleaned = country.trimmingCharacters(in: .whitespaces)
        return String(cleaned.prefix(3)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("CURRENT MATCH")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                if isLive {
                    Circle()
                        .fill(Color.live)
                        .frame(width: 6, height: 6)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parts.home)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.textPrimary)
                Text("vs")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
                Text(parts.away)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }

            Text(parts.subtitle)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Color.borderSoft, lineWidth: 1)
        )
    }
}

// MARK: - Section label

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(Color.textSubtle)
    }
}

// MARK: - Sidebar row

private enum SidebarRowAccessory: Equatable {
    case livePill
    case count(Int)
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let selected: Bool
    let accessory: SidebarRowAccessory?
    let collapsed: Bool
    let glassNamespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: collapsed ? 0 : 10) {
                if !collapsed {
                    Image(systemName: systemImage)
                        .font(.system(size: 13))
                        .foregroundStyle(selected ? Color.textPrimary : Color.textMuted)
                        .frame(width: 18)

                    Text(title)
                        .font(Typography.body)
                        .foregroundStyle(selected ? Color.textPrimary : Color.textMuted)

                    Spacer()

                    accessoryView

                } else {
                    ZStack {
                        Image(systemName: systemImage)
                            .font(.system(size: 15))
                            .foregroundStyle(selected ? Color.textPrimary : Color.textMuted)

                        // Collapsed: represent the accessory as a compact dot/dot+count.
                        if case .livePill = accessory {
                            Circle()
                                .fill(Color.live)
                                .frame(width: 6, height: 6)
                                .overlay(Circle().stroke(Color.bgBase, lineWidth: 1.5))
                                .offset(x: 10, y: -10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, collapsed ? 0 : 10)
            .padding(.vertical, collapsed ? 10 : 8)
            .frame(maxWidth: .infinity)
            .background(rowBackground)
            .overlay(alignment: .leading) {
                if selected {
                    Rectangle()
                        .fill(Color.live)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? title : "")
    }

    @ViewBuilder
    private var rowBackground: some View {
        if selected {
            LiquidGlassBackground(intensity: 1.0)
                .matchedGeometryEffect(id: "sidebar.selection.glass", in: glassNamespace)
        } else if hovering {
            LiquidGlassBackground(intensity: 0.45)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .livePill:
            LivePill()
        case .count(let n):
            Text("\(n)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.textSubtle)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3).stroke(Color.borderSoft, lineWidth: 1)
                )
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Liquid glass selection background

/// Frosted, translucent "liquid glass" treatment for the sidebar selection /
/// hover highlight. Uses `.regularMaterial` for the frost, a top-bright sheen
/// gradient for the wet-glass feel, and a gradient rim stroke for the edge
/// highlight. `intensity` scales the sheen + stroke + shadow so the same
/// primitive renders both the strong selected state and a lighter hover state.
private struct LiquidGlassBackground: View {
    let intensity: Double

    private let corner: CGFloat = 8

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.regularMaterial)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.10 * intensity),
                            Color.primary.opacity(0.02 * intensity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.22 * intensity),
                            Color.primary.opacity(0.05 * intensity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        }
        .shadow(color: Color.black.opacity(0.14 * intensity), radius: 5, y: 2)
    }
}

// MARK: - New Session button

private struct NewSessionButton: View {
    let collapsed: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: collapsed ? 0 : 8) {
                Image(systemName: "plus")
                    .font(.system(size: collapsed ? 14 : 11, weight: .bold))
                    .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
                if !collapsed {
                    Text("NEW SESSION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
                    Spacer()
                }
            }
            .padding(.horizontal, collapsed ? 0 : 12)
            .padding(.vertical, collapsed ? 10 : 10)
            .frame(maxWidth: .infinity)
            .background(hovering ? Color.bgSubtle : Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(hovering ? Color.bbBorder : Color.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? "New session" : "")
    }
}

// MARK: - Footer controls (theme toggle + collapse toggle + status)

private struct SidebarFooterControls: View {
    let collapsed: Bool
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(spacing: 8) {
            if collapsed {
                IconButton(systemImage: theme.mode == .dark ? "sun.max" : "moon",
                           help: theme.mode == .dark ? "Light mode" : "Dark mode") {
                    theme.toggleMode()
                }
                IconButton(systemImage: "sidebar.left", help: "Expand sidebar") {
                    theme.toggleSidebar()
                }
            } else {
                FooterPillButton(
                    systemImage: theme.mode == .dark ? "sun.max" : "moon",
                    label: theme.mode == .dark ? "LIGHT MODE" : "DARK MODE"
                ) {
                    theme.toggleMode()
                }
            }
        }
    }
}

private struct FooterPillButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(hovering ? Color.bgSubtle : Color.bgRaised, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? Color.textPrimary : Color.textMuted)
                .frame(width: 36, height: 36)
                .background(hovering ? Color.bgSubtle : Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(Color.borderSoft, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

private struct StatusDot: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.textSubtle)
        }
    }
}
