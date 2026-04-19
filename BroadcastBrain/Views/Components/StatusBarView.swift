import SwiftUI

struct StatusBarView: View {
    let matchTitle: String
    let isAirplane: Bool
    let latencyMs: Int?

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }
}
