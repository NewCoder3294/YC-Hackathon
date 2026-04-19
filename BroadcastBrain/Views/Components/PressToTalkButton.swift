import SwiftUI

/// Always-on mic toggle. Click to start listening, click again to stop.
///
/// Named `PressToTalkButton` for file-path continuity with earlier commits;
/// the semantic is now toggle-to-listen (continuous capture + segment STT).
struct PressToTalkButton: View {
    let isListening: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Waveform(isActive: isListening)

            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.live : Color.bgRaised)
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(Color.live, lineWidth: isListening ? 3 : 2)
                        .frame(width: 80, height: 80)
                    Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(isListening ? Color.textPrimary : Color.live)
                }
            }
            .buttonStyle(.plain)

            Text(isListening ? "LISTENING · TAP TO STOP" : "TAP TO LISTEN")
                .font(Typography.chip)
                .foregroundStyle(isListening ? Color.live : Color.textSubtle)
                .animation(.easeInOut(duration: 0.15), value: isListening)
        }
    }
}
