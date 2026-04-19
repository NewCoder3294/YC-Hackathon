import SwiftUI

/// Subtle dotted grid background. Matches the `bg-data-grid.svg` tile from
/// reference/brand-assets/backgrounds — 20pt cell, 1px dot at each intersection.
struct DottedGrid: View {
    var dotColor: Color = Color.bbBorder.opacity(0.8)
    var spacing: CGFloat = 20
    var dotSize: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let cols = Int(size.width / spacing) + 2
                let rows = Int(size.height / spacing) + 2
                for c in 0...cols {
                    for r in 0...rows {
                        let x = CGFloat(c) * spacing
                        let y = CGFloat(r) * spacing
                        let rect = CGRect(
                            x: x - dotSize / 2,
                            y: y - dotSize / 2,
                            width: dotSize,
                            height: dotSize
                        )
                        ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}
