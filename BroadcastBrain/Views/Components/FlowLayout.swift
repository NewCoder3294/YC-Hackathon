import SwiftUI

/// Wrapping horizontal layout — like `HStack` but lines wrap when they run out
/// of width. Used for pill clusters (example prompts, tag strips, etc.).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let containerWidth = proposal.width, containerWidth > 0 else {
            return .zero
        }
        return arrange(subviews: subviews, containerWidth: containerWidth).total
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrange(subviews: subviews, containerWidth: bounds.width)
        for (index, point) in arrangement.origins.enumerated() {
            let p = CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y)
            subviews[index].place(at: p, proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, containerWidth: CGFloat)
        -> (total: CGSize, origins: [CGPoint])
    {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth && x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
