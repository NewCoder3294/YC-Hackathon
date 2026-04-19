import SwiftUI

struct LatencyTag: View {
    let ms: Int

    var body: some View {
        Text("\(ms)ms")
            .font(Typography.chip)
            .foregroundStyle(Color.textSubtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.bgSubtle, in: RoundedRectangle(cornerRadius: 3))
    }
}
