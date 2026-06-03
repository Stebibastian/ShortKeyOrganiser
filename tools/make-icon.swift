#!/usr/bin/env swift
import AppKit

// Erzeugt ein App-Icon (blaues Squircle + weißes ⌘-Symbol) als .iconset-Ordner.
// Aufruf: swift make-icon.swift <ziel-iconset-ordner>

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppSupport/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir,
                                         withIntermediateDirectories: true)

func tintedSymbol(pointSize: CGFloat, color: NSColor) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: "command", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }
    let size = base.size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width)), pixelsHigh: Int(ceil(size.height)),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    base.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
    color.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: size)
    image.addRepresentation(rep)
    return image
}

func renderIcon(pixel: CGFloat) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(pixel), pixelsHigh: Int(pixel),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: pixel, height: pixel)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = pixel * 0.085
    let background = NSRect(x: 0, y: 0, width: pixel, height: pixel).insetBy(dx: inset, dy: inset)
    let radius = background.width * 0.2237   // nahe der macOS-Squircle-Rundung
    let path = NSBezierPath(roundedRect: background, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.38, green: 0.47, blue: 0.97, alpha: 1),
        NSColor(srgbRed: 0.29, green: 0.22, blue: 0.80, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -90)

    if let symbol = tintedSymbol(pointSize: pixel * 0.46, color: .white) {
        let size = symbol.size
        let rect = NSRect(x: (pixel - size.width) / 2, y: (pixel - size.height) / 2,
                          width: size.width, height: size.height)
        symbol.draw(in: rect)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let variants: [(pixel: CGFloat, name: String)] = [
    (16,  "icon_16x16.png"),    (32,   "icon_16x16@2x.png"),
    (32,  "icon_32x32.png"),    (64,   "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),  (256,  "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),  (512,  "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),  (1024, "icon_512x512@2x.png"),
]

for variant in variants {
    guard let data = renderIcon(pixel: variant.pixel) else {
        FileHandle.standardError.write("Fehler beim Rendern von \(variant.name)\n".data(using: .utf8)!)
        exit(1)
    }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(variant.name)
    try? data.write(to: url)
    print("  \(variant.name)")
}
print("✓ Iconset: \(outDir)")
