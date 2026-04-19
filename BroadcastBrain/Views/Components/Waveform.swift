import SwiftUI

struct Waveform: View {
    let isActive: Bool
    let barCount = 20

    @State private var tick = 0.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.live)
                    .frame(width: 3, height: heightFor(i))
                    .animation(.easeInOut(duration: 0.2), value: tick)
            }
        }
        .frame(height: 38)
        .task(id: isActive) {
            if isActive { await pump() }
        }
    }

    private func heightFor(_ i: Int) -> CGFloat {
        guard isActive else { return 4 }
        let seed = Double(i) * 0.6 + tick
        let v = abs(sin(seed)) * 32 + 6
        return v
    }

    private func pump() async {
        while !Task.isCancelled && isActive {
            tick += .pi / 3
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
    }
}
