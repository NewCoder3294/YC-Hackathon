import SwiftUI

struct SportradarBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.verified)
                .font(.system(size: 10))
            Text("Sportradar")
                .font(Typography.chip)
                .foregroundStyle(Color.textSubtle)
        }
    }
}
