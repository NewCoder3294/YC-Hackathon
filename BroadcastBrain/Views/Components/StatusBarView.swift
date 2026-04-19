import SwiftUI

struct StatusBarView: View {
    let matchTitle: String
    /// Sport of the current session. When nil (e.g. on the Archive list
    /// where no single sport applies), falls back to a generic icon.
    let sport: Sport?
    let latencyMs: Int?

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
        }
        .padding(.horizontal, 16)
        .padding(.top, 34)
        .padding(.bottom, 12)
        .background(Color.bgRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bbBorder).frame(height: 1)
        }
    }
}
