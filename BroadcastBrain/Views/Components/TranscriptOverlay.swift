import SwiftUI

struct TranscriptOverlay: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 10))
                .foregroundStyle(Color.textSubtle)
            Text("You said: \(text)")
                .font(Typography.body)
                .foregroundStyle(Color.textMuted)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 4))
    }
}
