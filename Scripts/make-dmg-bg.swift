#!/usr/bin/env swift
// Generates the DMG background image (dark gradient + arrow + drag hint).
// Output path is the first CLI arg, default /tmp/dmg-bg.png.

import AppKit

let outPath = CommandLine.arguments.dropFirst().first ?? "/tmp/dmg-bg.png"

let size = NSSize(width: 660, height: 400)

// Render into an explicit opaque (no-alpha) RGB bitmap at 1x. Finder rejects
// alpha-channel PNGs as window backgrounds, and a 2x lockFocus capture also
// confuses it — so we control the bitmap precisely.
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 3,            // RGB, no alpha
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Deep celestial gradient — kept dark so Finder's icon-view labels render in
// white (Finder picks light label text + halo on dark DMG backgrounds).
let g = NSGradient(colors: [
    NSColor(srgbRed: 0.03, green: 0.03, blue: 0.08, alpha: 1),
    NSColor(srgbRed: 0.09, green: 0.07, blue: 0.16, alpha: 1),
])!
g.draw(in: NSRect(origin: .zero, size: size), angle: 90)

// Extra darkening toward the bottom where the icon labels sit, so the label
// text stays clearly white against it.
let vignette = NSGradient(colors: [
    NSColor.black.withAlphaComponent(0.0),
    NSColor.black.withAlphaComponent(0.45),
])!
vignette.draw(in: NSRect(origin: .zero, size: size), angle: 270)

let centered = NSMutableParagraphStyle()
centered.alignment = .center

// Big arrow between the two icon slots.
let arrowAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 56, weight: .light),
    .foregroundColor: NSColor.white.withAlphaComponent(0.55),
    .paragraphStyle: centered,
]
NSAttributedString(string: "→", attributes: arrowAttrs)
    .draw(in: NSRect(x: 240, y: 170, width: 180, height: 80))

// "Drag to install" hint at the bottom.
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.85),
    .paragraphStyle: centered,
]
NSAttributedString(string: "Drag Dubai Iqama into Applications", attributes: hintAttrs)
    .draw(in: NSRect(x: 0, y: 50, width: 660, height: 24))

// Title at the top.
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: centered,
]
NSAttributedString(string: "Dubai Iqama", attributes: titleAttrs)
    .draw(in: NSRect(x: 0, y: 340, width: 660, height: 30))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render PNG\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outPath))
print(outPath)
