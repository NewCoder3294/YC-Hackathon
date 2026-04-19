import SwiftUI

/// Archive tab — stores past sessions (transcripts, notes, stat cards).
/// Shows a list on entry; clicking a row opens its read-only detail.
struct ArchivesListView: View {
    @Environment(AppStore.self) private var store
    @State private var query: String = ""
    @State private var filter: ArchiveFilter = .all

    var body: some View {
        if let id = store.selectedArchiveId,
           let session = store.sessionStore.sessions.first(where: { $0.id == id }) {
            detailView(session: session)
        } else {
            listView
        }
    }

    // MARK: - List

    private var listView: some View {
        VStack(spacing: 0) {
            StatusBarView(
                matchTitle: "Archive",
                isAirplane: true,
                latencyMs: nil
            )

            header

            ScrollView {
                LazyVStack(spacing: 18, pinnedViews: [.sectionHeaders]) {
                    if store.sessionStore.sessions.isEmpty {
                        emptyState
                    } else if filteredGroups.isEmpty {
                        noMatchState
                    } else {
                        ForEach(filteredGroups, id: \.label) { group in
                            Section {
                                VStack(spacing: 8) {
                                    ForEach(group.sessions) { session in
                                        ArchiveEntryRow(
                                            session: session,
                                            isCurrent: session.id == store.currentSession.id
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            store.selectedArchiveId = session.id
                                        }
                                    }
                                }
                            } header: {
                                groupHeader(group)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }

    // MARK: - Header + filters

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Text("PAST SESSIONS")
                    .font(Typography.sectionHead)
                    .tracking(1.4)
                    .foregroundStyle(Color.textSubtle)

                countPill("\(store.sessionStore.sessions.count) TOTAL")

                Spacer()

                searchField.frame(width: 240)

                filterPicker
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSubtle)
            TextField("Search sessions", text: $query)
                .textFieldStyle(.plain)
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSubtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
    }

    private var filterPicker: some View {
        GlassSegmentedPicker(
            selection: $filter,
            options: ArchiveFilter.allCases,
            label: { $0.label }
        )
    }

    private func countPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.textSubtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bbBorder, lineWidth: 1))
    }

    // MARK: - Groups

    private var filteredGroups: [ArchiveGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base = store.sessionStore.sessions
            .sorted { $0.createdAt > $1.createdAt }
            .filter { s in
                let matchesQuery = q.isEmpty || s.title.lowercased().contains(q)
                let matchesFilter: Bool = {
                    switch filter {
                    case .all:    return true
                    case .active: return !s.statCards.isEmpty || !s.transcript.isEmpty
                    case .empty:  return s.statCards.isEmpty && s.transcript.isEmpty && s.notes.isEmpty && s.researchMessages.isEmpty
                    }
                }()
                return matchesQuery && matchesFilter
            }
        return ArchiveGroup.group(base)
    }

    private func groupHeader(_ group: ArchiveGroup) -> some View {
        HStack(spacing: 10) {
            Text(group.label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.textSubtle)
            Rectangle().fill(Color.bbBorder).frame(height: 1)
            Text("\(group.sessions.count)")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
        }
        .padding(.vertical, 6)
        .background(Color.bgBase)
    }

    // MARK: - Empty / no match

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.textSubtle)
            Text("No sessions yet")
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
            Text("Go live — BroadcastBrain will save every match here.")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }

    private var noMatchState: some View {
        Text("No sessions match ‘\(query)’")
            .font(Typography.chip)
            .foregroundStyle(Color.textSubtle)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bbBorder, lineWidth: 1))
    }

    // MARK: - Detail wrapper

    private func detailView(session: Session) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: { store.selectedArchiveId = nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("All sessions")
                            .font(Typography.body)
                    }
                    .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.bgRaised)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.bbBorder).frame(height: 1)
            }

            ArchiveDetailView(session: session)
        }
    }
}

// MARK: - Filter enum

enum ArchiveFilter: String, CaseIterable, Identifiable, Hashable {
    case all, active, empty
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:    return "ALL"
        case .active: return "ACTIVE"
        case .empty:  return "EMPTY"
        }
    }
}

// MARK: - Group

struct ArchiveGroup {
    let label: String
    let sessions: [Session]

    static func group(_ sessions: [Session]) -> [ArchiveGroup] {
        let cal = Calendar.current
        let now = Date()
        var buckets: [(String, Int, [Session])] = []  // (label, sortKey, sessions)

        for s in sessions {
            let label: String
            let sortKey: Int
            if cal.isDateInToday(s.createdAt) {
                label = "TODAY"; sortKey = 0
            } else if cal.isDateInYesterday(s.createdAt) {
                label = "YESTERDAY"; sortKey = 1
            } else if let days = cal.dateComponents([.day], from: s.createdAt, to: now).day, days < 7 {
                label = "EARLIER THIS WEEK"; sortKey = 2
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM d, yyyy"
                label = fmt.string(from: s.createdAt).uppercased()
                // Use negative days-ago so older dates sort after TODAY / YESTERDAY / WEEK
                let days = cal.dateComponents([.day], from: s.createdAt, to: now).day ?? 0
                sortKey = 3 + days
            }

            if let idx = buckets.firstIndex(where: { $0.0 == label }) {
                buckets[idx].2.append(s)
            } else {
                buckets.append((label, sortKey, [s]))
            }
        }

        return buckets
            .sorted { $0.1 < $1.1 }
            .map { ArchiveGroup(label: $0.0, sessions: $0.2) }
    }
}

// MARK: - Row

struct ArchiveEntryRow: View {
    let session: Session
    let isCurrent: Bool

    @State private var hovering = false

    private var isEmpty: Bool {
        session.statCards.isEmpty
            && session.transcript.isEmpty
            && session.notes.isEmpty
            && session.researchMessages.isEmpty
    }

    private var relativeTime: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: session.createdAt, relativeTo: Date())
    }

    private var absoluteTime: String {
        session.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var accentColor: Color {
        if isCurrent { return Color.live }
        if isEmpty { return Color.bbBorder }
        return Color.verified
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isEmpty ? Color.textMuted : Color.textPrimary)
                        .lineLimit(1)

                    if isCurrent {
                        tag("CURRENT", color: .live)
                    }

                    Spacer()

                    Text(relativeTime)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textMuted)
                    Text("·")
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                    Text(absoluteTime)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(hovering ? Color.textPrimary : Color.textSubtle)
                }

                metricRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? Color.bgHover : Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var metricRow: some View {
        if isEmpty {
            HStack(spacing: 6) {
                tag("EMPTY", color: .textSubtle)
                Text("No cards, transcript, notes, or questions yet")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
            }
        } else {
            HStack(spacing: 14) {
                if !session.statCards.isEmpty {
                    metric("\(session.statCards.count)", "CARDS", color: .verified)
                }
                if !session.transcript.isEmpty {
                    metric("\(session.transcript.count)", "CHARS", color: .textMuted)
                }
                if !session.notes.isEmpty {
                    metric("\(session.notes.split(separator: "\n").count)", "NOTE LINES", color: .textMuted)
                }
                if !session.researchMessages.isEmpty {
                    metric("\(session.researchMessages.count)", "Q&A", color: .textMuted)
                }
                Spacer()
            }
        }
    }

    private func metric(_ value: String, _ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.textSubtle)
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.3), lineWidth: 1))
    }
}
