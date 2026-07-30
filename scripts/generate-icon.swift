// scripts/generate-icon.swift
// Usage (from repo root): swift scripts/generate-icon.swift
import AppKit
import Foundation

let iconSize: CGFloat = 1024

let canvas = NSImage(size: NSSize(width: iconSize, height: iconSize))
canvas.lockFocus()

// Blue background — full bleed; iOS applies the squircle mask automatically
NSColor(red: 0, green: 122 / 255.0, blue: 1.0, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: iconSize, height: iconSize).fill()

// White curlybraces SF Symbol, centred in 64 % of the icon area
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 620, weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let pad = iconSize * 0.18
    let frame = NSRect(x: pad, y: pad, width: iconSize - pad * 2, height: iconSize - pad * 2)
    symbol.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1.0)
} else {
    // fallback: plain text braces if SF Symbol is unavailable
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 420, weight: .light),
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: "{}", attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(x: (iconSize - sz.width) / 2, y: (iconSize - sz.height) / 2))
}

canvas.unlockFocus()

// Render at 1x scale (1024x1024 pixels) using CGContext to avoid Retina 2x upscaling
// and to produce an 8-bit sRGB PNG as required by Xcode's asset catalog compiler.
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
guard let ctx = CGContext(
    data: nil,
    width: 1024,
    height: 1024,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    fputs("Error: failed to create CGContext\n", stderr); exit(1)
}

let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

// Re-draw directly into the 1x context
NSColor(red: 0, green: 122 / 255.0, blue: 1.0, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: iconSize, height: iconSize).fill()

if let symbol = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let pad = iconSize * 0.18
    let frame = NSRect(x: pad, y: pad, width: iconSize - pad * 2, height: iconSize - pad * 2)
    symbol.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1.0)
} else {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 420, weight: .light),
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: "{}", attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(x: (iconSize - sz.width) / 2, y: (iconSize - sz.height) / 2))
}

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = ctx.makeImage() else {
    fputs("Error: failed to get CGImage from context\n", stderr); exit(1)
}

let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: 1024, height: 1024)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Error: failed to encode PNG\n", stderr); exit(1)
}
let outPath = "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
do {
    try FileManager.default.createDirectory(
        atPath: (outPath as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true
    )
    try png.write(to: URL(fileURLWithPath: outPath))
    print("✓ App icon written to \(outPath)")
} catch {
    fputs("Error: \(error)\n", stderr); exit(1)
}
