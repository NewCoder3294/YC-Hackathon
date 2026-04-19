import SwiftUI

/// Segmented picker that slides a liquid-glass capsule behind the active
/// option. Uses `matchedGeometryEffect` so the highlight fluidly animates
/// between segments. Generic over any `Hashable & Identifiable` option.
struct GlassSegmentedPicker<Option: Hashable & Identifiable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    @Namespace private var glassNS

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.bgSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.bbBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selection = option
            }
        } label: {
            Text(label(option))
                .font(Typography.chip)
                .tracking(0.6)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSubtle)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        LiquidGlassCapsule()
                            .matchedGeometryEffect(id: "glass-pill", in: glassNS)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Rounded-rect variant of the sidebar glass background, sized for the picker.
private struct LiquidGlassCapsule: View {
    private let corner: CGFloat = 5
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.regularMaterial)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.12),
                            Color.primary.opacity(0.02),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.28),
                            Color.primary.opacity(0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
    }
}
