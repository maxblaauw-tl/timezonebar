import AppKit
import SwiftUI

/// How much of the globe to draw. Every stroke costs roughly a pixel of clearance, so the
/// mark has to shed lines as it shrinks or it fills in and reads as a solid ring.
enum GlobeDetail {
    case minimal   // circle + equator — anything under ~30px
    case simple    // adds the meridian
    case full      // adds two more latitudes — 128px and up

    /// Picks the densest variant that still reads at the given pixel size.
    static func forPixelSize(_ px: CGFloat) -> GlobeDetail {
        if px >= 128 { return .full }
        if px >= 30 { return .simple }
        return .minimal
    }
}

/// The app's mark: a geometric globe — outer circle, a meridian ellipse for the 3D read,
/// and horizontal latitude lines. Drawn as a stroked path so it stays crisp at 16pt in the
/// menu bar and at 1024pt in the app icon.
struct GlobeMark: Shape {
    var detail: GlobeDetail = .full

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = side * 0.46

        var p = Path()

        // Outer circle
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

        // Meridian: a narrow vertical ellipse, same height as the globe
        if detail != .minimal {
            let mx = r * 0.44
            p.addEllipse(in: CGRect(x: c.x - mx, y: c.y - r, width: mx * 2, height: r * 2))
        }

        // Equator: the full horizontal chord
        p.move(to: CGPoint(x: c.x - r, y: c.y))
        p.addLine(to: CGPoint(x: c.x + r, y: c.y))

        // Two more latitudes, chord-width so they stop inside the circle
        if detail == .full {
            let dy = r * 0.51
            let half = (r * r - dy * dy).squareRoot()
            for offset in [-dy, dy] {
                p.move(to: CGPoint(x: c.x - half, y: c.y + offset))
                p.addLine(to: CGPoint(x: c.x + half, y: c.y + offset))
            }
        }

        return p
    }
}

// MARK: - Menu bar image

/// The menu bar needs a real template `NSImage` rather than a SwiftUI shape: template
/// images are drawn from their alpha channel, so macOS tints them correctly for light and
/// dark menu bars and inverts them while the menu is open.
enum MenuBarIcon {
    static let plain = make(scrubbed: false)
    static let scrubbed = make(scrubbed: true)

    static func image(scrubbed: Bool) -> NSImage { scrubbed ? self.scrubbed : plain }

    private static func make(scrubbed: Bool) -> NSImage {
        let size = NSSize(width: 16, height: 15)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.15)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)

            // Leave room bottom-trailing for the scrubbing dot.
            let inset: CGFloat = scrubbed ? 2.4 : 1.1
            var globe = rect.insetBy(dx: inset * 0.5, dy: inset * 0.5)
            if scrubbed {
                globe.origin.y += 1.1
                globe.origin.x -= 0.6
            }
            // Menu bar images are drawn at 2x on Retina, so `.simple` still resolves.
            ctx.addPath(GlobeMark(detail: .simple).path(in: globe).cgPath)
            ctx.strokePath()

            if scrubbed {
                let d: CGFloat = 5.2
                ctx.fillEllipse(in: CGRect(x: rect.maxX - d, y: rect.minY, width: d, height: d))
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

// MARK: - App icon

/// The `.icns` artwork, rendered by `Tools/main.swift --icon`. A tinted squircle plate with
/// the globe on top, sized the way macOS app icons are: the plate inset inside the canvas so
/// it lines up with other icons in the Dock and Finder.
struct AppIconView: View {
    let size: CGFloat

    private var plate: CGFloat { size * 0.804 }

    /// Small sizes get a proportionally bigger, simpler globe so it still reads.
    private var globeScale: CGFloat {
        if size < 30 { return 0.70 }
        if size < 128 { return 0.66 }
        return 0.60
    }

    /// The floor matters more than the ratio at tiny sizes: 1pt is the thinnest stroke that
    /// survives rasterisation, and going thicker fills the globe in.
    private var strokeWidth: CGFloat {
        let ratio: CGFloat = size < 30 ? 0.085 : (size < 128 ? 0.052 : 0.040)
        return max(plate * ratio, size < 30 ? 1.0 : 1.15)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: plate * 0.2237, style: .continuous)

        ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.70, blue: 1.00),
                            Color(red: 0.13, green: 0.46, blue: 0.95),
                            Color(red: 0.05, green: 0.31, blue: 0.85),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                // Specular sheen across the top third.
                .overlay {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.30), location: 0),
                                .init(color: .white.opacity(0.05), location: 0.32),
                                .init(color: .clear, location: 0.55),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                .overlay {
                    shape.stroke(Color.white.opacity(0.22), lineWidth: max(plate * 0.005, 0.5))
                }
                .frame(width: plate, height: plate)
                .shadow(color: .black.opacity(0.20), radius: plate * 0.03, y: plate * 0.018)

            GlobeMark(detail: .forPixelSize(size))
                .stroke(Color.white, style: StrokeStyle(
                    lineWidth: strokeWidth, lineCap: .round, lineJoin: .round
                ))
                .frame(width: plate * globeScale, height: plate * globeScale)
                // The shadow only muddies things below 128px.
                .shadow(color: Color(red: 0.02, green: 0.16, blue: 0.45).opacity(size >= 128 ? 0.35 : 0),
                        radius: plate * 0.012, y: plate * 0.008)
        }
        .frame(width: size, height: size)
    }
}
