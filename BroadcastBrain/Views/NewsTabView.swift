import SwiftUI
import AppKit

struct NewsTabView: View {
    @Environment(AppStore.self) private var store

    @State private var items: [NewsItem] = []
    @State private var selectedLeague: String = "all"
    @State private var isLoading = false
    @State private var isSynthesizing = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    @State private var selectionMode = false
    @State private var selectedIds: Set<String> = []

    private let leagueFilters: [(key: String, label: String)] = [
        ("all",        "ALL"),
        ("nfl",        "NFL"),
        ("nba",        "NBA"),
        ("mlb",        "MLB"),
        ("nhl",        "NHL"),
        ("epl",        "EPL"),
        ("mls",        "MLS"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            if let msg = errorMessage {
                Text(msg)
                    .font(Typography.chip)
                    .foregroundStyle(Color.live)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgRaised)
            }
            if let msg = statusMessage {
                Text(msg)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgRaised)
            }

            if isLoading && items.isEmpty {
                Spacer()
                ProgressView("Fetching headlines…").progressViewStyle(.circular)
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                Text("No headlines yet. Tap Refresh.")
                    .font(Typography.body)
                    .foregroundStyle(Color.textMuted)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredItems) { item in
                            NewsRow(
                                item: item,
                                selectionMode: selectionMode,
                                isSelected: selectedIds.contains(item.id),
                                onToggleSelection: { toggleSelection(item) }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color.bgBase)
        .task { if items.isEmpty { await refresh() } }
    }

    private var filteredItems: [NewsItem] {
        selectedLeague == "all" ? items : items.filter { $0.leagueKey == selectedLeague }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("NEWS")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()

                Button(action: toggleSelectionMode) {
                    HStack(spacing: 4) {
                        Image(systemName: selectionMode ? "checkmark.square.fill" : "square")
                            .font(.system(size: 11))
                        Text(selectionMode
                             ? "\(selectedIds.count) SELECTED"
                             : "SELECT ARTICLES"
                        )
                        .font(Typography.chip)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectionMode ? Color.bgHover : Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
                    .foregroundStyle(Color.textPrimary)
                }
                .buttonStyle(.plain)

                Button(action: { Task { await refresh() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh").font(Typography.chip)
                    }
                    .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button(action: { Task { await synthesize() } }) {
                    HStack(spacing: 4) {
                        if isSynthesizing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(synthesizeButtonLabel).font(Typography.chip)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.live.opacity(canSynthesize ? 0.9 : 0.3), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSynthesize)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(leagueFilters, id: \.key) { filter in
                        leagueChip(filter)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bgBase)
        .overlay(Divider().background(Color.bbBorder), alignment: .bottom)
    }

    private var synthesizeButtonLabel: String {
        if selectionMode {
            return selectedIds.isEmpty
                ? "Select articles to synthesize"
                : "Synthesize \(selectedIds.count) selected"
        }
        return "Synthesize all to notes"
    }

    private func leagueChip(_ filter: (key: String, label: String)) -> some View {
        let selected = selectedLeague == filter.key
        return Button(action: { selectedLeague = filter.key }) {
            Text(filter.label)
                .font(Typography.chip)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? Color.live : Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(selected ? Color.white : Color.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var canSynthesize: Bool {
        guard !isSynthesizing else { return false }
        if selectionMode { return !selectedIds.isEmpty }
        return !items.isEmpty
    }

    private var synthesisPool: [NewsItem] {
        if selectionMode {
            return items.filter { selectedIds.contains($0.id) }
        }
        let scoped = filteredItems
        return scoped.isEmpty ? items : scoped
    }

    // MARK: - Actions

    private func toggleSelectionMode() {
        selectionMode.toggle()
        if !selectionMode { selectedIds.removeAll() }
    }

    private func toggleSelection(_ item: NewsItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        let fetched = await NewsService.fetchAllSportsNews(limit: 10)
        await MainActor.run {
            self.items = fetched
            self.isLoading = false
            if fetched.isEmpty { self.errorMessage = "Couldn't fetch headlines (check network)." }
        }
    }

    private func synthesize() async {
        let pool = synthesisPool
        guard !pool.isEmpty else { return }
        isSynthesizing = true
        errorMessage = nil
        let label = selectionMode ? "selected" : "filtered"
        statusMessage = "Reading \(pool.count) \(label) headline\(pool.count == 1 ? "" : "s")…"

        let matchTitle = store.matchCache?.title
        let playerNames = (store.matchCache?.players ?? []).map(\.name)

        // Short pause so the first message is readable before the request starts.
        try? await Task.sleep(nanoseconds: 250_000_000)
        await MainActor.run { self.statusMessage = "Writing the digest…" }

        do {
            let digest = try await GeminiService.synthesizeNews(
                headlines: pool,
                matchTitle: matchTitle,
                playerNames: playerNames,
                userCurated: selectionMode
            )
            await MainActor.run {
                self.statusMessage = "Appending to Research notes…"
                appendDigestToNotes(digest)
                self.isSynthesizing = false
                self.selectedIds.removeAll()
                self.statusMessage = "Saved to Research notes."
            }
        } catch {
            await MainActor.run {
                self.isSynthesizing = false
                self.statusMessage = nil
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func appendDigestToNotes(_ digest: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = df.string(from: Date())
        let header = "=== News digest · \(stamp) ==="
        let existing = store.currentSession.notes
        let combined = existing.isEmpty
            ? "\(header)\n\(digest)"
            : "\(existing)\n\n\(header)\n\(digest)"
        store.updateNotes(combined)
    }
}

private struct NewsRow: View {
    let item: NewsItem
    let selectionMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void

    @State private var hovered = false

    private var articleURL: URL? {
        guard let s = item.articleUrl, let url = URL(string: s) else { return nil }
        return url
    }

    private var strokeColor: Color {
        if selectionMode && isSelected { return Color.live }
        return hovered ? Color.textMuted : Color.bbBorder
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .top, spacing: 10) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? Color.live : Color.textSubtle)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.leagueLabel)
                            .font(Typography.chip)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(Color.textMuted)
                        if !item.published.isEmpty {
                            Text(item.published.prefix(10))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.textSubtle)
                        }
                        Spacer()
                        if !selectionMode && articleURL != nil {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .foregroundStyle(hovered ? Color.textPrimary : Color.textSubtle)
                        }
                    }
                    Text(item.headline)
                        .font(Typography.body)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(Typography.chip)
                            .foregroundStyle(Color.textMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (selectionMode && isSelected) ? Color.live.opacity(0.08)
                : (hovered ? Color.bgHover : Color.bgRaised),
                in: RoundedRectangle(cornerRadius: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(strokeColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectionMode && articleURL == nil)
        .onHover { hovered = $0 }
        .help(selectionMode
              ? (isSelected ? "Deselect" : "Select for synthesis")
              : (articleURL?.absoluteString ?? "No link available"))
    }

    private func handleTap() {
        if selectionMode {
            onToggleSelection()
        } else if let url = articleURL {
            NSWorkspace.shared.open(url)
        }
    }
}
