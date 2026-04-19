import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(message.role == .user ? Color.textPrimary : Color.live)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "YOU" : "BROADCASTBRAIN")
                    .font(Typography.chip)
                    .foregroundStyle(Color.textSubtle)
                Text(message.content)
                    .font(Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if message.role == .assistant {
                    if message.grounded {
                        SportradarBadge().padding(.top, 2)
                    } else {
                        Text("unverified")
                            .font(Typography.chip)
                            .foregroundStyle(Color.live)
                            .padding(.top, 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}
