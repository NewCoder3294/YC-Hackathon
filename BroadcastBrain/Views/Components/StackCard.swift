import SwiftUI

enum CardKind {
    case stat, precedent, counter, empty

    var stripeColor: Color {
        switch self {
        case .stat: return .verified
        case .precedent: return .esoteric
        case .counter: return .live
        case .empty: return .bbBorder
        }
    }
}

struct StackCard<Content: View>: View {
    let kind: CardKind
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(kind.stripeColor)
                .frame(width: 4)
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
