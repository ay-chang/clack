#!/usr/bin/env swift
// Builds the app icon and the menu bar template image from Resources/clack-mark.png.
//
// The source artwork is a black mark on an opaque white square with generous
// margins. Neither is what macOS wants, so this script:
//   1. keys out the white to recover an alpha channel (preserving antialiasing),
//   2. trims to the mark's bounding box,
//   3. composites it onto an Apple-grid squircle for the .icns, and
//   4. emits a black-with-alpha template PNG for the menu bar.
//
// Run via `make icon`.

import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let markPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/clack-mark.png"

guard let src = NSImage(contentsOfFile: markPath),
      let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil)
else { fputs("cannot read \(markPath)\n", stderr); exit(1) }

let w = srcCG.width, h = srcCG.height

// --- 1. Read pixels, build a black glyph with alpha = darkness. ---
var px = [UInt8](repeating: 0, count: w * h * 4)
guard let readCtx = CGContext(
    data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
readCtx.draw(srcCG, in: CGRect(x: 0, y: 0, width: w, height: h))

var minX = w, minY = h, maxX = -1, maxY = -1
var glyph = [UInt8](repeating: 0, count: w * h * 4)
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        let r = Double(px[i]), g = Double(px[i+1]), b = Double(px[i+2])
        let srcAlpha = Double(px[i+3]) / 255.0
        // Luminance -> darkness. White background becomes transparent.
        let lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        let a = max(0, min(1, (1.0 - lum) * srcAlpha))
        let a8 = UInt8(a * 255)
        glyph[i] = 0; glyph[i+1] = 0; glyph[i+2] = 0; glyph[i+3] = a8
        if a > 0.35 {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
}
guard maxX > minX, maxY > minY else { fputs("mark appears empty\n", stderr); exit(1) }

guard let glyphCtx = CGContext(
    data: &glyph, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
), let glyphFull = glyphCtx.makeImage() else { exit(1) }

// CoreGraphics origin is bottom-left; the scan above was top-down.
let cropRect = CGRect(
    x: minX, y: h - 1 - maxY,
    width: maxX - minX + 1, height: maxY - minY + 1
)
guard let mark = glyphFull.cropping(to: cropRect) else { exit(1) }
let markW = CGFloat(mark.width), markH = CGFloat(mark.height)

func write(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

// --- 2. App icon: the mark on a light squircle, Apple's 824/1024 content grid. ---
let S: CGFloat = 1024
guard let icon = CGContext(
    data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let inset = S * 0.1
let plate = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let radius = plate.width * 0.2237
let platePath = CGPath(
    roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil
)

icon.saveGState()
icon.addPath(platePath)
icon.clip()
// Very slightly warm off-white, so the icon reads as a surface rather than a hole
// when it sits on a white background.
let colors = [
    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
    CGColor(red: 0.937, green: 0.937, blue: 0.945, alpha: 1),
] as CFArray
if let g = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]
) {
    icon.drawLinearGradient(
        g,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end: CGPoint(x: plate.midX, y: plate.minY),
        options: []
    )
}
icon.restoreGState()

// Hairline edge for definition on light backgrounds.
icon.addPath(CGPath(
    roundedRect: plate.insetBy(dx: 1, dy: 1),
    cornerWidth: radius, cornerHeight: radius, transform: nil
))
icon.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
icon.setLineWidth(2)
icon.strokePath()

// The mark, sized to the plate and optically centred.
let targetW = plate.width * 0.60
let scale = targetW / markW
let drawn = CGRect(
    x: plate.midX - targetW / 2,
    y: plate.midY - (markH * scale) / 2,
    width: targetW, height: markH * scale
)
icon.draw(mark, in: drawn)

guard let iconImage = icon.makeImage() else { exit(1) }
write(iconImage, to: "\(outDir)/icon_1024.png")

// --- 3. Menu bar template: black with alpha, rendered at 4x. ---
// The mark is wide and solid, so matching the *height* of a typical SF Symbol
// makes it read much heavier than its neighbours. The display size is set in
// ClackApp.swift; this just needs enough resolution to downsample cleanly.
let barH: CGFloat = 44
let barW = (markW / markH) * barH
guard let bar = CGContext(
    data: nil, width: Int(barW.rounded()), height: Int(barH), bitsPerComponent: 8,
    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
bar.interpolationQuality = .high
bar.draw(mark, in: CGRect(x: 0, y: 0, width: barW, height: barH))
if let barImage = bar.makeImage() {
    write(barImage, to: "\(outDir)/MenuBarIcon.png")
}

print("mark \(Int(markW))x\(Int(markH)) -> icon_1024.png, MenuBarIcon.png (\(Int(barW))x\(Int(barH)))")
