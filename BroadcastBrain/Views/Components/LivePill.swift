import SwiftUI

struct LivePill: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.live)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
            Text("LIVE")
                .font(Typography.chip)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.live.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.live, lineWidth: 1))
        .onAppear { pulse = true }
    }
}
