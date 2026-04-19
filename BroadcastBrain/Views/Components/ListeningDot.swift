import SwiftUI

struct ListeningDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Color.live)
            .frame(width: 10, height: 10)
            .scaleEffect(pulse ? 1.3 : 0.8)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)
            .onAppear { pulse = true }
    }
}
