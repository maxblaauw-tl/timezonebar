import SwiftUI

/// Liquid Glass is a live effect that `ImageRenderer` can't rasterize, so the offscreen
/// preview tool flips this on to substitute a flat translucent fill. The app never sets it.
enum Appearance {
    static var flattenGlass = false
}

extension View {
    /// Liquid Glass background in the given shape.
    @ViewBuilder
    func glassBackground(_ glass: Glass = .regular, in shape: some Shape) -> some View {
        if Appearance.flattenGlass {
            self.background(Color.primary.opacity(0.06), in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
        } else {
            self.glassEffect(glass, in: shape)
        }
    }

    /// Glass button styling — `prominent` for the one primary action in a group.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if Appearance.flattenGlass {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        } else {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        }
    }

}

// Note: there is deliberately no `GlassEffectContainer` wrapper here. A container blends
// glass elements that sit closer together than its `spacing`, which is wrong for this
// panel's button rows — the prominent "Now" capsule grows lobes towards its neighbours.
// Every glass surface in the app is meant to stand on its own.

/// Shared metrics so the panel's nested shapes stay concentric.
enum Metrics {
    static let panelWidth: CGFloat = 420
    static let gutter: CGFloat = 14
    static let cardRadius: CGFloat = 13
    static let trackRadius: CGFloat = 9
    static let trackHeight: CGFloat = 30
}

/// Approximate row heights, used to give the scroll area a sensible height on its very first
/// layout pass — before `onGeometryChange` has reported the real one. These only need to be
/// roughly right, but they must not be zero: see the comment on `PanelView`'s frame.
/// `preview.sh` asserts they stay close to what the rows actually measure.
enum RowMetrics {
    static let localRow: CGFloat = 88   // taller than the rest: it carries the 00–24 scale
    static let cityRow: CGFloat = 79
    static let emptyHint: CGFloat = 68
    static let spacing: CGFloat = 3
    static let bottomPadding: CGFloat = 6

    static func estimatedHeight(cityCount: Int) -> CGFloat {
        let body = cityCount == 0
            ? emptyHint
            : CGFloat(cityCount) * (cityRow + spacing)
        return localRow + spacing + body + bottomPadding
    }
}
