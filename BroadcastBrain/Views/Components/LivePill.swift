import SwiftUI

struct LivePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.live)
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(Typography.chip)
                .foregroundStyle(Color.live)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.live.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.live.opacity(0.7), lineWidth: 1))
    }
}
