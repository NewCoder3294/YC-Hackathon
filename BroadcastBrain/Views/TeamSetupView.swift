import SwiftUI

struct TeamSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var teamInput: String = ""
    @State private var fetchService = GameFetchService()
    @State private var error: String? = nil
    @State private var isFetching = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()
            DottedGrid()

            VStack(spacing: 0) {
                Spacer()
                card
                Spacer()
            }
            .padding(40)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("BROADCASTBRAIN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.verified).frame(width: 6, height: 6)
                    Text("AIRPLANE MODE SAFE")
                        .font(Typography.chip)
                        .foregroundStyle(Color.verified)
                }
            }
            .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 20)

            Divider().background(Color.bbBorder)

            // Main content
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set up tonight's match.")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                    Text("Enter a team name — we'll fetch the roster, next game, and storylines.")
                        .font(Typography.body)
                        .foregroundStyle(Color.textMuted)
                }

                // Input
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSubtle)
                    TextField("e.g. Manchester City, Lakers, Yankees…", text: $teamInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.textPrimary)
                        .focused($focused)
                        .disabled(isFetching)
                        .onSubmit { startFetch() }
                }
                .padding(14)
                .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(
                    focused ? Color.verified.opacity(0.6) : Color.bbBorder, lineWidth: 1))

                // Progress / error
                if isFetching {
                    progressView
                } else if let err = error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.live)
                        Text(err)
                            .font(Typography.chip)
                            .foregroundStyle(Color.live)
                    }
                }

                // Actions
                HStack(spacing: 10) {
                    Button(action: startFetch) {
                        HStack(spacing: 6) {
                            if isFetching {
                                ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 13))
                            }
                            Text(isFetching ? "BUILDING CACHE…" : "BUILD CACHE")
                                .font(Typography.sectionHead)
                        }
                        .foregroundStyle(canFetch ? Color.bgBase : Color.textSubtle)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(canFetch ? Color.verified : Color.bgSubtle,
                                    in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canFetch)

                    // Only show skip if a cache already exists
                    if store.matchCache != nil {
                        Button("KEEP CURRENT MATCH") {
                            store.showingSetup = false
                        }
                        .buttonStyle(.plain)
                        .font(Typography.chip)
                        .foregroundStyle(Color.textSubtle)
                    }
                }
            }
            .padding(28)

            // Quick-pick suggestions
            Divider().background(Color.bbBorder)
            quickPicks
        }
        .background(Color.bgRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.bbBorder, lineWidth: 1))
        .frame(maxWidth: 560)
        .onAppear { focused = true }
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(FetchStep.allCases, id: \.self) { s in
                HStack(spacing: 8) {
                    stepIcon(s)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.rawValue)
                            .font(Typography.chip)
                            .foregroundStyle(labelColor(s))
                        if fetchService.step == s && !fetchService.stepDetail.isEmpty {
                            Text(fetchService.stepDetail)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.textSubtle)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bbBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func stepIcon(_ s: FetchStep) -> some View {
        let current = fetchService.step
        let idx     = FetchStep.allCases.firstIndex(of: s) ?? 0
        let curIdx  = FetchStep.allCases.firstIndex(of: current) ?? 0
        if idx < curIdx {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11)).foregroundStyle(Color.verified)
        } else if idx == curIdx {
            ProgressView().scaleEffect(0.6).frame(width: 11, height: 11)
        } else {
            Circle().stroke(Color.bbBorder, lineWidth: 1).frame(width: 9, height: 9)
                .padding(1)
        }
    }

    private func labelColor(_ s: FetchStep) -> Color {
        let idx    = FetchStep.allCases.firstIndex(of: s) ?? 0
        let curIdx = FetchStep.allCases.firstIndex(of: fetchService.step) ?? 0
        if idx < curIdx  { return Color.verified }
        if idx == curIdx { return Color.textPrimary }
        return Color.textSubtle
    }

    private var quickPicks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("QUICK PICK:")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.textSubtle)
                ForEach(suggestions, id: \.self) { team in
                    Button(team) {
                        teamInput = team
                        startFetch()
                    }
                    .buttonStyle(.plain)
                    .font(Typography.chip)
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bbBorder, lineWidth: 1))
                    .disabled(isFetching)
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
        }
    }

    private let suggestions = [
        "Manchester City","Arsenal","Real Madrid",
        "Los Angeles Lakers","Boston Celtics",
        "New York Yankees","Los Angeles Dodgers",
        "Toronto Maple Leafs","Edmonton Oilers",
    ]

    private var canFetch: Bool {
        !isFetching && !teamInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func startFetch() {
        let name = teamInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isFetching else { return }
        error = nil
        isFetching = true
        Task {
            do {
                let cache = try await fetchService.buildMatchCache(teamName: name)
                await MainActor.run {
                    store.loadMatchCache(cache)
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isFetching = false
                }
            }
        }
    }
}

extension FetchStep: CaseIterable {
    static var allCases: [FetchStep] {
        [.detectingSport, .findingGame, .fetchingRosters, .fetchingNews, .buildingCache, .done]
    }
}
