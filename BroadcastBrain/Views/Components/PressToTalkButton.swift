import SwiftUI

struct PressToTalkButton: View {
    let isListening: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Waveform(isActive: isListening)
            ZStack {
                Circle()
                    .fill(isListening ? Color.live : Color.bgRaised)
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(Color.live, lineWidth: isListening ? 3 : 2)
                    .frame(width: 80, height: 80)
                Image(systemName: "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isListening ? Color.textPrimary : Color.live)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isListening { onStart() } }
                    .onEnded { _ in if isListening { onStop() } }
            )
            Text(isListening ? "LISTENING · RELEASE TO SEND" : "HOLD TO TALK")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
        }
    }
}
