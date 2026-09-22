import SwiftUI

/// A one-day scrubber. The track is shaded by hour class (night / fringe / working hours),
/// a Liquid Glass handle marks the viewed instant, and a hairline marks the real current time.
struct TimeTrack: View {
    /// Start of the day this track covers, in its own timezone.
    let dayStart: Date
    /// Length of that day in seconds (DST-aware, so 23h/25h days work).
    let span: Double
    /// Seconds since `dayStart` for the viewed instant.
    let value: Double
    /// Seconds since `dayStart` for "now", or nil when now falls outside this day.
    let nowValue: Double?
    /// Hour class for each hour bucket in this day.
    let hourClasses: [HourClass]
    /// Draw the 00/06/12/18/24 scale underneath (first row only, to avoid clutter).
    var showScale: Bool = false

    var onScrub: (Double) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var dragging = false

    private let height = Metrics.trackHeight
    private let knobWidth: CGFloat = 13

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let frac = span > 0 ? min(max(value / span, 0), 1) : 0
                let shape = RoundedRectangle(cornerRadius: Metrics.trackRadius, style: .continuous)

                ZStack(alignment: .leading) {
                    LinearGradient(stops: gradientStops, startPoint: .leading, endPoint: .trailing)

                    // Convex sheen: bright at the top, faintly shaded at the bottom.
                    // Full height and gentle, so it reads as depth rather than a seam.
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(scheme == .dark ? 0.07 : 0.16), location: 0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(scheme == .dark ? 0.10 : 0.045), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )

                    // 06 / 12 / 18 guides
                    ForEach([6.0, 12.0, 18.0], id: \.self) { h in
                        Rectangle()
                            .fill(Color.primary.opacity(0.07))
                            .frame(width: 1)
                            .offset(x: w * (h * 3600 / max(span, 1)))
                    }

                    // Where "now" actually is
                    if let nowValue, span > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.28))
                            .frame(width: 1.5)
                            .offset(x: w * min(max(nowValue / span, 0), 1))
                    }

                    knob
                        .offset(x: (w - knobWidth) * frac)
                }
                .clipShape(shape)
                .overlay(shape.stroke(Color.primary.opacity(scheme == .dark ? 0.10 : 0.07), lineWidth: 0.5))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !dragging {
                                withAnimation(.smooth(duration: 0.18)) { dragging = true }
                            }
                            onScrub(min(max(g.location.x / w, 0), 1) * span)
                        }
                        .onEnded { _ in
                            withAnimation(.smooth(duration: 0.22)) { dragging = false }
                        }
                )
            }
            .frame(height: height)

            if showScale { scale }
        }
    }

    private var knob: some View {
        ZStack {
            Capsule()
                .fill(.clear)
                .glassBackground(.regular.interactive(), in: Capsule())
            Capsule()
                .fill(.white)
                .frame(width: 3)
                .padding(.vertical, 7)
                .shadow(color: .black.opacity(0.25), radius: 1)
        }
        .frame(width: knobWidth, height: height - 4)
        .scaleEffect(dragging ? 1.14 : 1, anchor: .center)
    }

    private var scale: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                ForEach([0.0, 6.0, 12.0, 18.0, 24.0], id: \.self) { h in
                    let frac = min(h * 3600 / max(span, 1), 1)
                    Text(h == 24 ? "24" : String(format: "%02d", Int(h)))
                        .font(.system(size: 8, weight: .medium).monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .frame(width: 18, alignment: h == 0 ? .leading : (h == 24 ? .trailing : .center))
                        .offset(x: (w - 18) * frac)
                }
            }
        }
        .frame(height: 10)
    }

    /// Hard-ish colour bands with a hair of blending at each hour boundary.
    private var gradientStops: [Gradient.Stop] {
        let n = Double(max(hourClasses.count, 1))
        var stops: [Gradient.Stop] = []
        for (i, cls) in hourClasses.enumerated() {
            let color = cls.trackColor(scheme)
            stops.append(.init(color: color, location: Double(i) / n + 0.004))
            stops.append(.init(color: color, location: Double(i + 1) / n - 0.004))
        }
        return stops.isEmpty ? [.init(color: .clear, location: 0)] : stops
    }
}
