#!/usr/bin/env swift
// Generates the GitHub social-preview (Open Graph) card: 1280x640, dark
// celestial theme, app name + tagline on the left, app screenshot on the right.
//
//   swift Scripts/make-social-preview.swift <screenshot.png> <out.png>

import AppKit

let args = Array(CommandLine.arguments.dropFirst())
let shotPath = args.first ?? "docs/screenshots/main-window.png"
let outPath = args.count > 1 ? args[1] : "docs/social-preview.png"

let W = 1280, H = 640
let size = NSSize(width: W, height: H)

// RGBA — a 24-bit no-alpha bitmap yields a nil NSGraphicsContext on macOS 26.
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

// 1. Diagonal celestial gradient.
let grad = NSGradient(colors: [
    rgb(0.05, 0.05, 0.12),
    rgb(0.16, 0.10, 0.26),
    rgb(0.30, 0.14, 0.30),
])!
grad.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 65)

// 2. Warm sun glow low-right (under where the screenshot sits).
let glow = NSGradient(colors: [
    rgb(1.0, 0.78, 0.42).withAlphaComponent(0.40), .clear,
])!
glow.draw(in: NSRect(x: 760, y: 120, width: 520, height: 520), relativeCenterPosition: .zero)

// 3. Faint sky-arc motif across the card.
cg.saveGState()
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
cg.setLineWidth(1.2)
cg.setLineDash(phase: 0, lengths: [3, 6])
let path = CGMutablePath()
let steps = 80
for i in 0...steps {
    let t = Double(i) / Double(steps)
    let x = 40 + t * Double(W - 80)
    let y = 360 + sin(t * .pi) * 150
    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
}
cg.addPath(path); cg.strokePath()
cg.restoreGState()

// Helpers ------------------------------------------------------------------

let para = NSMutableParagraphStyle(); para.alignment = .left

func draw(_ s: String, _ rect: NSRect, size fs: CGFloat, weight: NSFont.Weight,
          color: NSColor, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fs, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: para,
        .kern: tracking,
    ]
    NSAttributedString(string: s, attributes: attrs).draw(in: rect)
}

// 4. Left-column copy.
let gold = rgb(0.99, 0.82, 0.42)
let textSecondary = NSColor.white.withAlphaComponent(0.78)

draw("PRAYER TIMES", NSRect(x: 80, y: 470, width: 560, height: 40), size: 22, weight: .bold,
     color: gold, tracking: 6)
draw("Iqama", NSRect(x: 78, y: 392, width: 600, height: 80), size: 62, weight: .bold,
     color: .white)
draw("الفجر · الظهر · العصر · المغرب · العشاء",
     NSRect(x: 80, y: 350, width: 600, height: 34), size: 22, weight: .regular,
     color: textSecondary)
draw("Location-aware prayer times & iqama countdown,\nwith a celestial Liquid Glass UI.",
     NSRect(x: 80, y: 250, width: 580, height: 80), size: 24, weight: .medium,
     color: NSColor.white.withAlphaComponent(0.92))

for (i, line) in ["Menu-bar countdown", "Home-screen widgets", "Awqaf (UAE) · Aladhan worldwide"].enumerated() {
    let y = 150 - CGFloat(i) * 36
    // bullet dot
    cg.setFillColor(gold.cgColor)
    cg.fillEllipse(in: CGRect(x: 82, y: y + 7, width: 8, height: 8))
    draw(line, NSRect(x: 104, y: y - 4, width: 520, height: 30), size: 19, weight: .regular,
         color: textSecondary)
}

// 5. Right-side screenshot, rounded + shadowed.
if let shot = NSImage(contentsOfFile: shotPath) {
    let targetH: CGFloat = 540
    let aspect = shot.size.width / max(1, shot.size.height)
    let targetW = targetH * aspect
    let x = CGFloat(W) - targetW - 70
    let y = (CGFloat(H) - targetH) / 2
    let frame = NSRect(x: x, y: y, width: targetW, height: targetH)

    cg.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    let clip = NSBezierPath(roundedRect: frame, xRadius: 28, yRadius: 28)
    clip.addClip()
    shot.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1.0)
    cg.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("render failed\n".utf8)); exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print(outPath)
