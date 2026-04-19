import SwiftUI

struct StatusBarView<Trailing: View>: View {
    let matchTitle: String
    /// Sport of the current session. When nil (e.g. on the Archive list
    /// where no single sport applies), falls back to a generic icon.
    let sport: Sport?
    let latencyMs: Int?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sport?.symbolName ?? "sportscourt.fill")
                .foregroundStyle(Color.verified)
                .font(.system(size: 12))
            Text(matchTitle)
                .font(Typography.body)
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
            Spacer()
            if let ms = latencyMs {
                LatencyTag(ms: ms)
            }
            LivePill()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 34)
        .padding(.bottom, 14)
        .frame(height: 72, alignment: .bottom)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }
}

extension StatusBarView where Trailing == EmptyView {
    init(matchTitle: String, sport: Sport?, latencyMs: Int?) {
        self.matchTitle = matchTitle
        self.sport = sport
        self.latencyMs = latencyMs
        self.trailing = { EmptyView() }
    }
}
