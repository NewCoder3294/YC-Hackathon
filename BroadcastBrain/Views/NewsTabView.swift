import SwiftUI

struct NewsTabView: View {
    @Environment(AppStore.self) private var store

    @State private var items: [NewsItem] = []
    @State private var selectedLeague: String = "all"
    @State private var isLoading = false
    @State private var isSynthesizing = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

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
                            NewsRow(item: item)
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
            HStack {
                Text("NEWS")
                    .font(Typography.sectionHead)
                    .foregroundStyle(Color.textSubtle)
                Spacer()
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
                        Text("Synthesize to Research Notes").font(Typography.chip)
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
        !items.isEmpty && !isSynthesizing
    }

    // MARK: - Actions

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
        guard !items.isEmpty else { return }
        isSynthesizing = true
        errorMessage = nil
        statusMessage = "Synthesizing with Gemini…"

        let matchTitle = store.matchCache?.title
        let playerNames = (store.matchCache?.players ?? []).map(\.name)
        let pool = filteredItems.isEmpty ? items : filteredItems

        do {
            let digest = try await GeminiService.synthesizeNews(
                headlines: pool,
                matchTitle: matchTitle,
                playerNames: playerNames
            )
            await MainActor.run {
                appendDigestToNotes(digest)
                self.isSynthesizing = false
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

    var body: some View {
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
            }
            Text(item.headline)
                .font(Typography.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !item.description.isEmpty {
                Text(item.description)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
    }
}
