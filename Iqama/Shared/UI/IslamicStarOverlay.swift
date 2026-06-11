import SwiftUI

// A tiled field of 8-point stars (najmiyya) rendered with Canvas. Sized to
// the container; intended to be used at low opacity as a textural overlay.
struct IslamicStarOverlay: View {
    var tileSize: CGFloat = 64
    var strokeWidth: CGFloat = 0.6

    var body: some View {
        Canvas { gc, size in
            let cols = Int(ceil(size.width / tileSize)) + 1
            let rows = Int(ceil(size.height / tileSize)) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    let cx = CGFloat(c) * tileSize + tileSize / 2
                    let cy = CGFloat(r) * tileSize + tileSize / 2
                    let path = star8Path(center: CGPoint(x: cx, y: cy),
                                         radius: tileSize * 0.34)
                    gc.stroke(path, with: .color(.white), lineWidth: strokeWidth)
                }
            }
        }
    }

    private func star8Path(center: CGPoint, radius: CGFloat) -> Path {
        // Two interlocking squares offset by 45° form a classic 8-point star.
        Path { p in
            for offset in [CGFloat(0), .pi / 4] {
                p.move(to: point(at: 0 + offset, r: radius, c: center))
                for k in 1...4 {
                    p.addLine(to: point(at: CGFloat(k) * .pi / 2 + offset, r: radius, c: center))
                }
                p.closeSubpath()
            }
        }
    }

    private func point(at angle: CGFloat, r: CGFloat, c: CGPoint) -> CGPoint {
        CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
    }
}
