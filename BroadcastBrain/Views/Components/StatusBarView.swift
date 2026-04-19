import SwiftUI

struct StatusBarView<Trailing: View>: View {
    let matchTitle: String
    let isAirplane: Bool
    let latencyMs: Int?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane")
                .foregroundStyle(isAirplane ? Color.verified : Color.textSubtle)
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
    init(matchTitle: String, isAirplane: Bool, latencyMs: Int?) {
        self.matchTitle = matchTitle
        self.isAirplane = isAirplane
        self.latencyMs = latencyMs
        self.trailing = { EmptyView() }
    }
}
